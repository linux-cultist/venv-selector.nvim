# 🎉 venv-selector.nvim

A lightweight Neovim plugin to discover, browse, and activate Python virtual environments from inside Neovim — no restart required.

[![Neovim >=0.11](https://img.shields.io/badge/Neovim-%3E%3D0.11-blue)](https://neovim.io) [![License: MIT](https://img.shields.io/badge/license-MIT-brightgreen)](LICENSE)

![venv-selector screenshot](venvselect.png)

---

## Quick start

1. Add the plugin to your plugin manager (example below for `lazy.nvim`).
2. Open any Python file.
3. Trigger `:VenvSelect` or your mapped key (example `,v`).
4. Choose a virtual environment — the plugin sets `VIRTUAL_ENV` or `CONDA_PREFIX` and updates terminals opened afterward.

If you dont see your expected venvs in the picker, you can add your own searches. See `docs/USAGE.md` for examples.

---

## Features

- Switch virtual environments without restarting Neovim.
- Switch between multiple python files using multiple lsps in different buffers.
- PEP-723 metadata support (via `uv`).
- Discover venvs automatically in common places and your workspace.
- Terminals start with selected venv active (sets `VIRTUAL_ENV` or `CONDA_PREFIX`)
- Re-activates selected venv for the same workspace when you open a python file.
- Integrates with debuggers (nvim-dap / nvim-dap-python + debugpy), statuslines, and many pickers.
- Add your own custom searches (fd/find/ls/any command) and regex/template variable support.
- Picker backends: `telescope`, `fzf-lua`, `snacks`, `mini-pick`, `vim.ui.select`
- Integrations: Lualine, NvChad, optional DAP support
---


## Requirements

- Neovim >= 0.11
- `fd` or `fdfind` required for default searches
- A picker plugin (Telescope is shown in picture)
Optional:
- `nvim-dap`, `nvim-dap-python`, `debugpy` — for debugger integration
- `nvim-notify` — for nicer notifications
- Nerd Font — for icons in certain pickers/statuslines

---

## Install (example: lazy.nvim)

Add this to your plugin specs (example):
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

Notes:
- The plugin creates the `:VenvSelect` command and lazy-loading it by `ft = "python"` is recommended.
- The `:VenvSelectLog` command is available if you set the `log_level` option to `DEBUG` or `TRACE`.
- There is also the `:VenvSelectCache` command, only available if the `cached_venv_automatic_activation` option is `false` (default is `true`).

---

## Troubleshooting

Start with setting the `log_level` option to `TRACE` or `DEBUG` and then use the `VenvSelectLog` command after using `VenvSelect`. You will see a lot of information about what the plugin is doing. You may be able to understand what the problem is just from looking at the log.

If you still have issues, consult `docs/USAGE.md` or open an issue with `:VenvSelect` output and your search config.

---

## FAQ

Q: Do I need to restart Neovim after switching venvs?
A: No. Activation is done in-process; new terminals opened after selection inherit the environment.

Q: Will this change my system Python?
A: No. It only sets environment variables within Neovim and spawned child processes.

Q: Can I automatically activate venvs per-project?
A: The plugin caches the last selected venv per workspace and can re-activate it when you open files in the same workspace.

Q: How does the plugin detect venvs?
A: By searching for interpreter binaries and recognizing common venv manager locations. PEP-723 metadata is supported if `uv` is available.

---

## Links & docs

- Usage & examples: `docs/USAGE.md`
- Options reference: `docs/OPTIONS.md`
- Public API: `docs/API.md`
- Changelog: `CHANGELOG.md`
- License: `LICENSE`

