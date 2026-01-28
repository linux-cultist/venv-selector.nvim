<div align="center">
  <h1>🎉 Python Venv Selector</h1>
  <p>A small Neovim plugin to browse and activate Python virtual environments inside Neovim.</p>
  <img src="venvselect.png" alt="venv-selector screenshot" />
</div>

---

## 📚 Table of contents

- [Quick start](#quick-start)
- [Features](#features)
- [Requirements](#requirements)
- [Install (quick)](#install-quick)
- [Configuration & docs](#configuration--docs)
- [Troubleshooting (short)](#troubleshooting-short)
- [Contributing & license](#contributing--license)
- [Changelog](#changelog)

---



<a name="quick-start"></a>
## 🚀 Quick start

1. Ensure prerequisites (see [Requirements](#requirements) below)
2. Install the plugin with your plugin manager (see [Install](#install-quick) below)
3. Open a Python file, trigger the picker (example keymap `,v`), and select a venv to activate.

---

<a name="requirements"></a>
## 🧩 Requirements

- Neovim >= 0.11
- `fd` (or `fdfind`) for default searches (you can add custom searches with other tools)
- A supported picker plugin (default is `telescope` in the quick install instructions)
- Optional:
  - `nvim-dap`, `nvim-dap-python`, and `debugpy` for debugger integration
  - `nvim-notify` for improved notifications
  - A Nerd Font for icons in statuslines/pickers

---

<a name="features"></a>
## ⚡️ Features

- Switch virtual environments from inside Neovim without restarting
- Finds virtual environments in default locations automatically (including your workspace and cwd directories)
- Reactivates virtual environments from cache when you open a python file in the same CWD as before
- Terminals opened from neovim has the selected venv activated (setting `VIRTUAL_ENV` or `CONDA_PREFIX`)
- Built-in support for many venv managers:
  - `python -m venv`, `poetry`, `pipenv`, `anaconda` / `miniconda`, `pyenv`, `virtualenvwrapper`, `hatch`, `pipx`
- PEP-723 metadata script support with `uv`: The plugin will detect the metadata and pick or create the correct virtual environment
- Add your own searches (use `fd`, `find`, `ls`, or any command that lists interpreters)
- Use regular expressions to discover virtual environments along with template variables:
  - `$CWD`, `$WORKSPACE_PATH`, `$FILE_DIR`, `$CURRENT_FILE`
- Callbacks:
  - `on_telescope_result_callback` to format picker results in telescope
  - `on_venv_activate_callback` to run custom code on activation
- Integrations:
  - Statusline support (Lualine, NvChad)
  - Optional DAP support via `nvim-dap` / `nvim-dap-python` and `debugpy`
- Picker support:
  - `telescope`, `fzf-lua`, `snacks`, `mini-pick`, native `vim.ui.select`


---

<a name="install-quick"></a>
## 🛠️ Install (quick)

One-line `lazy.nvim` example (quick copy/paste):

```lua
{
  "linux-cultist/venv-selector.nvim",
  dependencies = {
    { "nvim-telescope/telescope.nvim", branch = "*", dependencies = { "nvim-lua/plenary.nvim" } },
  },
  opts = {
      options = {}, -- if you need custom searches, they go here
      search = {} -- any options you want to set goes here
  },
  ft = "python",           -- lazy-load on Python files
  keys = { { ",v", "<cmd>VenvSelect<cr>" } }, -- example keybind to open the picker
}
```

See `docs/USAGE.md` for a full description of creating your own custom searches.

---

<a name="configuration--docs"></a>
## 📝 Configuration & docs

- [Detailed usage of the plugin](docs/USAGE.md)
- [Full configuration reference](docs/OPTIONS.md)
- [Public API and helper functions](docs/API.md)
- [Release notes / recent news](CHANGELOG.md)

---

<a name="troubleshooting-short"></a>
## 🛟 Troubleshooting (short)

- My venvs don't show up:
  - Add a custom search that targets the folder where your venvs live.
  - Ensure your search regex matches `python` vs `python.exe` on Windows.
  - If using workspace searches, ensure your Python LSP is attached so `$WORKSPACE_PATH` is populated.
- VenvSelect is slow:
  - Limit the scope of your `fd` queries (search specific directories).
  - Avoid unnecessary `-H` (hidden) flag unless you need dot-prefixed folders.
  - Disable default searches you don't need and add targeted ones.
- Conda/anaconda issues:
  - Ensure conda searches set `type = "anaconda"` so `CONDA_PREFIX` and related env vars are set correctly.

---

<a name="contributing--license"></a>
## 🤝 Contributing & license

- Read `CONTRIBUTING.md` if present. Small focused PRs with examples are easiest to review.
- License: see `LICENSE`.

---

<a name="changelog"></a>
## 📰 Changelog

Recent news and release notes are in `CHANGELOG.md`.

---

