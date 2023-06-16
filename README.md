# Deferring of all NeoVim diagnostics

NeoVim has an option (`update_in_insert`) to defer displaying diagnostics when
in insert mode. When enabled, diagnostics are disabled when entering insert
mode, and re-enabled when leaving insert mode. This reduces the amount of noise
caused by irrelevant diagnostics.

Unfortunately, this option _only_ applies to signs, underlines, and virtual
text. If you display the number of diagnostics in your statusline, automatically
populate location/quickfix lists with new diagnostics, or really do anything
else with the diagnostics you're out of luck.

In addition, `update_in_insert` doesn't apply to normal mode, meaning any
changes made in normal mode may result in new diagnostics being displayed.

Finally, when a popup menu is displayed (such as when using a `completefunc`),
Vim enters normal mode. If you then insert text by cycling through the available
items, new diagnostics are displayed.

It all comes down to the same problem: language servers typically produce
diagnostics as you type, but diagnostics are rarely useful when you are still
editing text.

nvim-dd tries to solve this problem by deferring _all_ diagnostics. This means
no annoying diagnostics while you are typing, and no need to handle deferring
every time you use the `vim.diagnostic` API yourself (e.g. in a statusline).

To illustrate this, here's what it looks like when you edit a Lua file without
nvim-dd:

[Without nvim-dd](https://github.com/yorickpeterse/nvim-dd/assets/86065/8588e17a-26f8-43e7-adc3-83cbd11e8913)

Note how the statusline changes as we're typing, and the new signs/underlines
that are produced.

Here's what it looks like _with_ nvim-dd:

[With nvim-dd](https://github.com/yorickpeterse/nvim-dd/assets/86065/947d85ec-deee-4162-9fd7-de389b5bb34b)

While the statusline and signs/underlines still change, they change less
frequently and not while we're in insert mode.

## How it works

nvim-dd hijacks `vim.lsp.diagnostic.on_publish_diagnostics`. Every time new
diagnostics come in, nvim-dd checks what to do. If you are in insert mode or a
popup menu is visible, the diagnostics are cached in a table. If you are not in
insert mode, the diagnostics are scheduled for publishing to NeoVim using a
timer. New changes made will cancel the existing timer. When exiting insert
mode, nvim-dd schedules all cached diagnostics using the same timer mechanism.

The result of this setup is that you can type all you want in insert mode, and
never be bothered by new (irrelevant) diagnostics. When leaving insert mode you
aren't _immediately_ bombarded with new diagnostics. When editing in normal
mode, diagnostics are only produced a certain time after your last edit.

This approach comes with one downside: if you use a plugin that expects
diagnostics to be available _immediately_ after the language server sends them
to NeoVim, said plugin probably won't work.

## Requirements

NeoVim 0.6 or newer is required, as this plugin uses the new `vim.diagnostic`
API. As of October 2021 this means you need to build NeoVim from the `master`
branch.

## Installation

First install this plugin using your plugin manager of choice. For example, when
using vim-plug use the following:

    Plug 'https://gitlab.com/yorickpeterse/nvim-dd.git'

Once installed, add the following Lua snippet to your `init.lua`:

    require('dd').setup()

And that's it!

## Configuration

You can configure nvim-dd as follows:

```lua
require('dd').setup({
  -- The time to wait before displaying newly produced diagnostics.
  timeout = 1000
})
```

## License

All source code in this repository is licensed under the Mozilla Public License
version 2.0, unless stated otherwise. A copy of this license can be found in the
file "LICENSE".
