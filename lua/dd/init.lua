local M = {}
local fn = vim.fn
local lsp = vim.lsp
local api = vim.api

local version = vim.version()

if version.major == 0 and version.minor < 6 then
  error('NeoVim version 0.6.0 or newer is required')
end

local function buffer_cache()
  local cache = {}
  local mt = {
    __index = function(table, buffer)
      table[buffer] = {}

      api.nvim_buf_attach(buffer, false, {
        on_detach = function()
          table[buffer] = nil
        end,
      })

      return table[buffer]
    end,
  }

  setmetatable(cache, mt)

  return cache
end

local original_on_publish = lsp.diagnostic.on_publish_diagnostics

-- Diagnostics that were produced while in insert mode.
local cached = buffer_cache()

-- Diagnostics produced while not in insert mode. These will be published
-- automatically after a short period of time.
local pending = buffer_cache()

local config = {
  -- The time (in milliseconds) after which diagnostics should be produced.
  timeout = 1000,
}

-- The various modes that for which we don't want diagnostics to show while we
-- are in those modes.
local ignore_modes = { i = true, ic = true, ix = true, s = true }

local function should_cache()
  -- In insert mode we don't want the diagnostics to show up, even if we wait a
  -- long time after we stop typing.
  --
  -- When displaying the popup menu, (Neo)Vim enters normal mode, even though it
  -- appears as if (Neo)Vim is in insert mode. In this case we also don't want
  -- diagnostics to show up just yet.
  local mode = api.nvim_get_mode().mode

  return fn.pumvisible() == 1 or ignore_modes[mode]
end

-- Schedules the flushing of diagnostics.
--
-- This function _does not_ capture the data and instead reads it from the
-- cache. This is deliberate because the data can be rather large, and it seems
-- Neovim/libuv holds on to the closure for quite long, resulting in an increase
-- in memory usage as the number of diagnostics processed goes up.
local function schedule(buffer, client)
  return vim.defer_fn(function()
    local data = cached[buffer][client]

    if not data then
      return
    end

    cached[buffer][client] = nil

    -- It's possible that at this point the state has changed such that we
    -- _don't_ want to show diagnostics anymore (e.g. we've entered insert mode
    -- again).
    --
    -- If new diagnostics were produced, this callback would have been cancelled
    -- by now. As such we'll just defer the diagnostics again.
    if should_cache() then
      M.defer(data.result, data.ctx, data.cfg)
      return
    end

    original_on_publish(nil, data.result, data.ctx, data.cfg)
  end, config.timeout)
end

function M.defer(result, ctx, config)
  local client = ctx.client_id
  local buffer = vim.uri_to_bufnr(result.uri)

  if pending[buffer][client] then
    pending[buffer][client]:stop()
    pending[buffer][client] = nil
  end

  cached[buffer][client] = { result = result, ctx = ctx, config = config }

  if should_cache() then
    return
  end

  pending[buffer][client] = schedule(buffer, client)
end

function M.flush()
  local buffer = api.nvim_get_current_buf()

  for _, data in pairs(cached[buffer]) do
    pending[buffer][data.ctx.client_id] = schedule(buffer, data.ctx.client_id)
  end
end

function M.setup(options)
  if options then
    config = vim.tbl_extend('force', config, options)
  end

  if not lsp.diagnostic.on_publish_diagnostics then
    error('vim.lsp.diagnostic.on_publish_diagnostics is undefined.')
  end

  vim.cmd([[
    augroup defer_diagnostics
      autocmd!
      au InsertLeave * lua require('dd').flush()
    augroup END
  ]])

  lsp.diagnostic.on_publish_diagnostics = function(_, result, ctx, config)
    M.defer(result, ctx, config)
  end
end

return M
