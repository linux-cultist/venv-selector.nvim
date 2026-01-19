# 🎉 Python Venv Selector

<p align="center">
  <img src="venvselect.png" alt="venv-selector screenshot" />
</p>

A small Neovim plugin to browse and activate Python virtual environments inside Neovim.  
This repository keeps a short, focused README and moves detailed usage, configuration, and API documentation into the `docs/` folder.

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

- Switch virtual environments inside Neovim without restarting
- Browse and activate venvs found on disk (using configurable searches)
- Built-in support for many venv managers:
  - `python -m venv`, `poetry`, `pipenv`, `anaconda` / `miniconda`, `pyenv` (and plugins), `virtualenvwrapper`, `hatch`, `pipx`
- PEP-723 / `uv` script support: detect inline script metadata and use `uv`-resolved interpreters
- Configurable searches (use `fd`, `find`, `ls`, or any command that lists interpreters)
- Use regular expressions to discover interpreters and custom search templates using these placeholders:
  - `$CWD`, `$WORKSPACE_PATH`, `$FILE_DIR`, `$CURRENT_FILE`
- Callbacks:
  - `on_telescope_result_callback` to format picker results
  - `on_venv_activate_callback` to run custom code on activation
- Integrations:
  - Statusline support (Lualine, NvChad)
  - Optional DAP support via `nvim-dap` / `nvim-dap-python` and `debugpy`
- Picker support:
  - `telescope`, `fzf-lua`, `snacks`, `mini-pick`, native `vim.ui.select`
- Options for caching, environment variable handling (`VIRTUAL_ENV` / `CONDA_PREFIX`), notifications, and more


---

<a name="install-quick"></a>
## 🛠️ Install (quick)

One-line `lazy.nvim` example (quick copy/paste):

```lua
{
  "linux-cultist/venv-selector.nvim",
  dependencies = {
    { "nvim-telescope/telescope.nvim", branch = "0.1.x", dependencies = { "nvim-lua/plenary.nvim" } },
  },
  opts = {},
  ft = "python",           -- lazy-load on Python files
  keys = { { ",v", "<cmd>VenvSelect<cr>" } }, -- example keybind to open the picker
}
```

See `docs/SEARCHES.md` for a full description of creating your own custom searches.

---

<a name="configuration--docs"></a>
## 📝 Configuration & docs

- [Creating your own searches](docs/SEARCHES.md)
- [Full configuration reference](docs/OPTIONS.md)
- [Public API and helper functions](docs/API.md)
- [Long-form examples (statuslines, callbacks)](examples/)
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

