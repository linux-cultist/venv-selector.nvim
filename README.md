<div align="center">
  <h1>🎉 venv-selector.nvim</h1>
  <p>Discover and activate Python virtual environments inside Neovim - no restart required.</p>
  <p>
    <a href="https://neovim.io"><img alt="Neovim >=0.11" src="https://img.shields.io/badge/Neovim-%3E%3D0.11-blue"></a>
    <a href="LICENCE.md"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-brightgreen"></a>
    <a href="README.md">
      <img alt="README" src="https://img.shields.io/badge/README-blue">
    </a>
    <a href="docs/USAGE.md">
      <img alt="USAGE" src="https://img.shields.io/badge/USAGE-blue">
    </a>
    <a href="docs/API.md">
      <img alt="API" src="https://img.shields.io/badge/API-blue">
    </a>
    <a href="docs/OPTIONS.md">
      <img alt="OPTIONS" src="https://img.shields.io/badge/OPTIONS-blue">
    </a>
  </p>

  <p>
    <img src="venvselect.png" alt="venv-selector screenshot" style="max-width:720px; width:100%; height:auto;">
  </p>
</div>


<br>

## ⚡️ Features

- 🌍 Discover virtual environments automatically in common places and your workspaces:
  - 🐍 Python (python3 -m venv venv)
  - 📦 Poetry
  - 🪪 Pipenv
  - 🐼 Anaconda
  - 🧩 Miniconda
  - 🧰 Pyenv (including pyenv-virtualenv and pyenv-win-venv plugins)
  - 🔁 Virtualenvwrapper
  - 🥚 Hatch
  - 🧰 Pipx
- 🔍 [Create your own searches](docs/USAGE.md#🔎-creating-your-own-searches)
- 🔁 Switch between virtual environments in the same or different project/workspace
- 🧾 [PEP-723 (`uv`) integration](docs/USAGE.md#🧾-pep-723-uv-integration).
- 🖥️ Terminals start with selected venv active (sets `VIRTUAL_ENV` or `CONDA_PREFIX`).
- 🔄 Re-activates virtual environment for project/workspace when you open a python file.
- 🧩 Integrates with debuggers (nvim-dap / nvim-dap-python + debugpy), statuslines, and many pickers.
- 🧰 Picker backends: `telescope`, `fzf-lua`, `snacks`, `mini-pick`, `vim.ui.select`
- 🎛️ Integrations with status bars: [Lualine](docs/USAGE.md#🎛️-support-for-lualine-and-nvchad-statusbars), [NvChad](docs/USAGE.md#🎛️-support-for-lualine-and-nvchad-statusbars)
- ⚙️ Many [options](docs/OPTIONS.md) to control behavior.

<br>


## 🚀 Quick start

1. Add the plugin to your plugin manager (example below for `lazy.nvim`).
2. Open any Python file.
3. Trigger `:VenvSelect` or your mapped key (example `,v`).
4. Choose a virtual environment.
5. Optionally open other python files in other projects and do steps 2-4 again.
6. You can now switch between their buffers and the plugin remembers the selected venv for each project.

The plugin configures your LSP to use the selected venv and also sets `VIRTUAL_ENV` or `CONDA_PREFIX` for use in terminals started from Neovim.

If you don't see your expected venvs in the picker, you can add your own searches. See [Creating your own searches](docs/USAGE.md#🔎-creating-your-own-searches) for examples.

<br>

## 🛠️ Installation (example: lazy.nvim)

Add this to your plugin specs (example):

```lua
{
  "linux-cultist/venv-selector.nvim",
  dependencies = {
    { "nvim-telescope/telescope.nvim", version = "*", dependencies = { "nvim-lua/plenary.nvim" } }, -- optional: you can also use fzf-lua, snacks, mini-pick instead.
  },
  ft = "python", -- Load when opening Python files
  keys = {
    { ",v", "<cmd>VenvSelect<cr>" }, -- Open picker on keymap
  },
  ft = "python",
  keys = { { ",v", "<cmd>VenvSelect<cr>" } }, -- example keybind
  opts = {
    options = {}, -- plugin-wide options
    search = {}   -- custom search definitions
  },
}
```

With the above settings, the plugin is lazy-loaded and activated on python files. The `:VenvSelect` command becomes available to select a venv for your currently opened python project.

The `:VenvSelectLog` command is available if you set the `log_level` [option](docs/OPTIONS.md) to `DEBUG` or `TRACE`. This shows a detailed log of what the plugin is doing when you pick a virtual environment in the picker.

The `:VenvSelectCache` command is only available if the `cached_venv_automatic_activation` [option](docs/OPTIONS.md) is `false`. This means you have turned off automatic activation of cached venvs and this command will let you manually activate them from cache.

<br>
    
## 🗞️ Important updates

- 2026-02-15 — 🔒 LSP gate added to prevent concurrent LSP operations (stop/start races). Also support for switching between multiple Python projects and PEP-723 `uv` metadata files and remembering the venv for each.
- 2025-09-30 — 🆕 Minimum Neovim now **0.11**; LSP servers are expected to be configured by the user via `vim.lsp.config`.
- 2025-08-27 — ✅ Regexp-branch merged into `main`. If you need the older behavior you can pin the `v1` branch (note: `v1` is no longer actively updated).

<br>
    
## 📚 About these docs

These docs are structured into several categories:

- [USAGE](docs/USAGE.md) - How to use the plugin
- [API](docs/API.md) - How to interact with the plugin from code
- [OPTIONS](docs/OPTIONS.md) - How to configure options

<br>

## 🧩 Requirements

- Neovim >= 0.11
- `fd` or `fdfind` required for default searches
- A picker plugin (Telescope is shown in picture)
- `nvim-dap`, `nvim-dap-python`, `debugpy` — for debugger integration (optional)
- `nvim-notify` — for nicer notifications (optional)
- Nerd Font — for icons in certain pickers/statuslines (optional)

<br>

## 🛟 Troubleshooting

Start with setting the `log_level` option to `TRACE` or `DEBUG` and then use the `:VenvSelectLog` command after using `:VenvSelect`.

```lua
{
  options = {
    log_level = "TRACE" -- enable VenvSelectLog command
  }
}
```

See if you can understand the problem from the log. If you still have issues, open an issue with `:VenvSelectLog` output and your search config.

<br>

## ❓ FAQ

- **Do I need to restart Neovim after switching venvs?** No — activation is done in-process; new terminals opened after selection inherit the environment.

- **Will this change my system Python?** No — it only sets environment variables within Neovim and spawned child processes.

- **Can I automatically activate venvs per-project?** The plugin caches the last selected venv per workspace and can re-activate it when you open files in the same workspace.

- **How does the plugin detect venvs?** By searching for interpreter binaries and recognizing common venv manager locations. PEP-723 metadata is supported if `uv` is available.
