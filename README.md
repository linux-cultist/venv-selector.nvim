<div align="center">
  <h1>🎉 venv-selector.nvim</h1>
  <p>A lightweight Neovim plugin to discover, browse, and activate Python virtual environments from inside Neovim — no restart required.</p>

  <!-- Badges -->
  <p>
    <a href="https://neovim.io"><img alt="Neovim >=0.11" src="https://img.shields.io/badge/Neovim-%3E%3D0.11-blue"></a>
    <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-brightgreen"></a>
    <a href="#"><img alt="Lua" src="https://img.shields.io/badge/Lua-5.x-lightgrey"></a>
  </p>

  <!-- Screenshot -->
  <p>
    <img src="venvselect.png" alt="venv-selector screenshot" style="max-width:720px; width:100%; height:auto;">
  </p>
</div>

---

## 🚀 TL;DR / Quick start

1. Install the plugin (example below for `lazy.nvim`).
2. Open any Python file.
3. Run `:VenvSelect` or press your mapped key (example: `,v`).
4. Select a virtualenv — the plugin sets `VIRTUAL_ENV` or `CONDA_PREFIX` and new terminals inherit it.

---

## ⚡️ Features

- In-editor venv switching (no Neovim restart).
- Auto-discovery of common venv locations and workspace roots.
- Re-activation of cached venv per workspace/CWD.
- Terminals spawned after activation inherit venv environment.
- PEP-723 (`uv`) script support.
- Integrations: telescope, fzf-lua, snacks, mini-pick, vim.ui.select, Lualine, NvChad, nvim-dap, debugpy.

---

## 🛠️ Install (example: lazy.nvim)

Add this to your plugin specs:

```lua
{
  "linux-cultist/venv-selector.nvim",
  dependencies = {
    { "nvim-telescope/telescope.nvim", version = "*", dependencies = { "nvim-lua/plenary.nvim" } },
  },
  ft = "python",
  keys = { { ",v", "<cmd>VenvSelect<cr>" } },
  opts = {
    options = {}, -- plugin options
    search = {}   -- custom search definitions
  },
}
```

Notes:
- The plugin provides `:VenvSelect` (picker) and `:VenvSelectLog` (debug logs).
- Lazy-load by `ft = "python"` is recommended for performance.

---

## ⚙️ Minimal configuration (Lua)

```lua
require("venv-selector").setup({
  options = {
    picker = "telescope", -- or "fzf-lua", "snacks", "mini-pick", "vim.ui.select", "auto"
  },
  search = {
    -- add custom searches here (see docs/USAGE.md)
  },
})
-- Example keymap
vim.keymap.set("n", ",v", "<cmd>VenvSelect<cr>", { desc = "Venv selector" })
```

---

## 🧰 Usage notes

- Terminals opened after activation inherit `VIRTUAL_ENV` or `CONDA_PREFIX`.
- To find venvs not detected by defaults, add a custom `search` entry (see `docs/USAGE.md`).
- For PEP-723 (`uv`) script support, install `uv` and configure `uv_script` search if needed.

---

## 🛟 Troubleshooting

1. Enable debug logging: set `log_level` to `DEBUG` or `TRACE` and run `:VenvSelectLog`.
2. If venvs don't appear, test the search command in your shell to ensure it prints interpreter paths.
3. On Windows, match `python.exe` (e.g. `Scripts\\python.exe$`).
4. If workspace-based searches use `$WORKSPACE_PATH`, ensure the Python LSP is attached.

---

## 🔗 Links & docs

- Usage & examples: `docs/USAGE.md`  
- Options reference: `docs/OPTIONS.md`  
- Public API: `docs/API.md`  
- Changelog: `CHANGELOG.md`  
- License: `LICENSE`

---