<div align="center">
  <img src="assets/banner.svg" alt="venv-selector.nvim banner" width="100%" style="max-width:1200px;">
</div>

<br>

<h1 align="center">🎉 venv-selector.nvim</h1>

<p align="center">
  Discover and activate Python virtual environments from inside Neovim — no restart required.
</p>

<p align="center">
  <a href="https://neovim.io"><img alt="Neovim >=0.11" src="https://img.shields.io/badge/Neovim-%3E%3D0.11-61dafb"></a>
  <a href="LICENCE.md"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-brightgreen"></a>
  <a href="https://github.com/linux-cultist/venv-selector.nvim/actions"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/linux-cultist/venv-selector.nvim/ci.yml?branch=main"></a>
</p>

---

## What is this?

`venv-selector.nvim` is a small Neovim plugin that helps you find, choose, and activate Python virtual environments (venvs/conda envs) for the current workspace. It sets `VIRTUAL_ENV` or `CONDA_PREFIX` for Neovim and processes spawned from it, and aims to integrate nicely with pickers (Telescope, fzf-lua, etc.), statuslines, and debuggers.

The plugin focuses on:
- fast discovery of venvs in common locations and the workspace,
- seamless activation without restarting Neovim,
- easy integration with existing pickers and statuslines,
- reliable handling across buffers and terminals.

---

## Demo

![screenshot](venvselect.png)

---

## Quick start

1. Install the plugin with your plugin manager (examples below).
2. Open any Python file or your project root.
3. Run `:VenvSelect` (or your mapped shortcut).
4. Pick a virtual environment — the plugin activates it without restarting Neovim.

New terminals opened after selection inherit the selected environment.

---

## Features

- Switch virtual environments in-process (no Neovim restart).
- Per-workspace caching of the last selected venv; optional automatic activation when opening files in that workspace.
- Search strategies: workspace scans, common manager directories, manual paths, and customizable commands.
- PEP-723 metadata support where available.
- Integrations: Telescope, fzf-lua, `mini-pick`, `vim.ui.select`, lualine/NvChad statusline components, nvim-dap / debugpy compatibility.
- Multiple picker backends supported so the plugin adapts to your workflow.

---

## Requirements

- Neovim >= 0.11
- `fd` (or `fdfind`) recommended for fast searching (configurable)
- A picker plugin (Telescope, fzf-lua, etc.) for nicer interactive selection (optional but recommended)
- Optional: `nvim-dap`, `nvim-dap-python`, `debugpy` for debugger integration
- Optional: Nerd Font for statusline/picker icons

---

## Installation

Example for `lazy.nvim`:

```lua
{
  "linux-cultist/venv-selector.nvim",
  dependencies = {
    { "nvim-telescope/telescope.nvim", version = "*", dependencies = { "nvim-lua/plenary.nvim" } },
  },
  ft = "python",
  keys = { { ",v", "<cmd>VenvSelect<cr>" } }, -- example keybind
  opts = {
    options = {}, -- plugin-wide options
    search = {}   -- custom search definitions
  },
}
```

Example for `packer.nvim`:

```lua
use {
  "linux-cultist/venv-selector.nvim",
  requires = { "nvim-lua/plenary.nvim" },
  ft = "python",
  config = function()
    require("venv-selector").setup {}
  end
}
```

---

## Basic usage

- `:VenvSelect` — open the picker to choose a virtual environment.
- `:VenvSelectCache` — view/clear the cached workspace selection (availability depends on options).
- `:VenvSelectLog` — dump plugin logs (useful when `log_level = "DEBUG"` or `"TRACE"`).

Configuration is done by calling `require("venv-selector").setup(opts)`. See `docs/OPTIONS.md` for all available options and their defaults.

---

## Example config snippet

```lua
require("venv-selector").setup {
  options = {
    -- Automatically re-apply the last used venv for a workspace
    cached_venv_automatic_activation = true,
    -- Log level: "ERROR", "WARN", "INFO", "DEBUG", "TRACE"
    log_level = "INFO",
  },
  search = {
    -- Add or override searches (fd/find or custom shell commands)
  },
}
```

---

## Customization & integrations

- Statusline: there is a lualine component at `lua/lualine/components/venv-selector.lua`.
- Picker backends: `telescope`, `fzf-lua`, `mini-pick`, `snacks`, and native `vim.ui.select` are supported. See `docs/USAGE.md` for examples on integrating with each picker.
- Debugger: `nvim-dap` / `nvim-dap-python` users can configure their adapter to use the selected interpreter.

---

## Troubleshooting

- If you don't see expected venvs in the picker, check:
  - your `search` configuration,
  - that `fd` is installed (if you're relying on it).
- Increase `log_level` to `DEBUG` or `TRACE`, reproduce the issue, then run `:VenvSelectLog` and include that output when opening issues.

---

## Links & docs

- Usage & examples: `docs/USAGE.md`
- Options reference: `docs/OPTIONS.md`
- Public API: `docs/API.md`
- Changelog: `CHANGELOG.md`
- License: `LICENCE.md`

---

## Contributing

Contributions, bug reports, and feature requests are welcome. Please follow the guidelines in `CONTRIBUTING.md`. When opening issues, include `:VenvSelectLog` output if applicable and a short reproduction.

---

## License

MIT — see `LICENCE.md` for details.

---