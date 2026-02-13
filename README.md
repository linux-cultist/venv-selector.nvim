<div align="center">
  <img src="assets/banner.svg" alt="venv-selector.nvim banner" width="100%" style="max-width:1200px;">
</div>

  <h1>🎉 venv-selector.nvim</h1>
<p>Discover and activate Python virtual environments inside Neovim - no restart required.</p>
  <div align="center">
  <p>
    <a href="https://neovim.io"><img alt="Neovim >=0.11" src="https://img.shields.io/badge/Neovim-%3E%3D0.11-blue"></a>
    <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-brightgreen"></a>
  </p>

  <p>
    <img src="venvselect.png" alt="venv-selector screenshot" style="max-width:720px; width:100%; height:auto;">
  </p>
</div>

<br>

## 🚀 Quick start

1. Add the plugin to your plugin manager (example below for `lazy.nvim`).
2. Open any Python file.
3. Trigger `:VenvSelect` or your mapped key (example `,v`).
4. Choose a virtual environment — the plugin sets `VIRTUAL_ENV` or `CONDA_PREFIX` and updates terminals opened afterward.

If you don't see your expected venvs in the picker, you can add your own searches. See `docs/USAGE.md` for examples.

<br>

## ⚡️ Features

- Switch virtual environments without restarting Neovim.
- Switch between multiple python files using multiple LSPs in different buffers.
- PEP-723 metadata support (via `uv`).
- Discover venvs automatically in common places and your workspace.
- Terminals start with selected venv active (sets `VIRTUAL_ENV` or `CONDA_PREFIX`).
- Re-activates selected venv for the same workspace when you open a Python file.
- Integrates with debuggers (nvim-dap / nvim-dap-python + debugpy), statuslines, and many pickers.
- Add your own custom searches (fd/find/ls/any command) and regex/template variable support.
- Picker backends: `telescope`, `fzf-lua`, `snacks`, `mini-pick`, `vim.ui.select`
- Integrations: Lualine, NvChad, optional DAP support

<br>

## 🧩 Requirements

- Neovim >= 0.11
- `fd` or `fdfind` required for default searches
- A picker plugin (Telescope is shown in picture)
- `nvim-dap`, `nvim-dap-python`, `debugpy` — for debugger integration (optional)
- `nvim-notify` — for nicer notifications (optional)
- Nerd Font — for icons in certain pickers/statuslines 

<br>

## 🛠️ Install (example: lazy.nvim)

Add this to your plugin specs (example):

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

Notes:
- The plugin creates the `:VenvSelect` command and lazy-loading it by `ft = "python"` is recommended.
- The `:VenvSelectLog` command is available if you set the `log_level` option to `DEBUG` or `TRACE`.
- There is also the `:VenvSelectCache` command, only available if the `cached_venv_automatic_activation` option is `false` (default is `true`).

<br>

## 🛟 Troubleshooting

Start with setting the `log_level` option to `TRACE` or `DEBUG` and then use the `:VenvSelectLog` command after using `:VenvSelect`.

See if you can understand the problem from the log. If you still have issues, open an issue with `:VenvSelectLog` output and your search config.

<br>

## ❓ FAQ

- **Do I need to restart Neovim after switching venvs?** No — activation is done in-process; new terminals opened after selection inherit the environment.

- **Will this change my system Python?** No — it only sets environment variables within Neovim and spawned child processes.

- **Can I automatically activate venvs per-project?** The plugin caches the last selected venv per workspace and can re-activate it when you open files in the same workspace.

- **How does the plugin detect venvs?** By searching for interpreter binaries and recognizing common venv manager locations. PEP-723 metadata is supported if `uv` is available.


<br>

## 🔗 Links & docs

- Usage & examples: `docs/USAGE.md`
- Options reference: `docs/OPTIONS.md`
- Public API: `docs/API.md`
- Changelog: `CHANGELOG.md`
- License: `LICENSE`
