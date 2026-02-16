# 🧩 Public API — venv-selector.nvim

This document is a concise, developer-focused reference for the public API exported by
`require("venv-selector")`. It documents the exposed functions, their signatures,
brief descriptions, return values, usage examples, and important notes / gotchas.

Quick import
```lua
local vs = require("venv-selector")
```

Table of contents
- Quick reference
- Detailed API (functions)
- Notes & types
- Examples
- See also

---

## ⚡ Quick reference

| Function | Signature | Returns | Short description |
|---|---:|---|---|
| `setup` | `vs.setup(conf)` | `nil` | Initialize plugin: validate prerequisites, register autocmds & commands. |
| `python` | `vs.python()` | `string | nil` | Active Python interpreter path (full path) or `nil`. |
| `venv` | `vs.venv()` | `string | nil` | Active virtualenv root directory or `nil`. |
| `source` | `vs.source()` | `string | nil` | Name of the search that found the active venv (e.g. `"poetry"`). |
| `workspace_paths` | `vs.workspace_paths()` | `string[]` | Workspace root folders detected via LSP for current buffer. |
| `cwd` | `vs.cwd()` | `string` | Neovim current working directory. |
| `file_dir` | `vs.file_dir()` | `string | nil` | Directory of current buffer/file, or `nil`. |
| `activate_from_path` | `vs.activate_from_path(python_path, env_type?)` | `nil` | Programmatic activation by interpreter path. |
| `deactivate` | `vs.deactivate()` | `nil` | Remove active venv from PATH & unset env vars; restore baseline LSP. |
| `stop_lsp_servers` | `vs.stop_lsp_servers()` | `nil` | Stop plugin-managed python LSP clients for the current buffer. |

---

## 🧾 Detailed API

### vs.setup(conf)
- Signature: `vs.setup(conf)`
- Parameters:
  - `conf` (table | nil): Plugin configuration table — see `docs/OPTIONS.md` for the full schema.
- Returns: `nil`
- Purpose: Initialize the plugin. Validates Neovim version and fd binary, sets up notifications and highlights, registers autocmds & user commands.
- Example:
```lua
require("venv-selector").setup({
  options = {
    fd_binary_name = "fd",
    cached_venv_automatic_activation = true,
    -- ...
  },
  search = {
    -- custom searches...
  }
})
```
- Notes:
  - Call this once from your plugin configuration (e.g. in your lazy.nvim spec `opts` or `setup`).
  - If prerequisites fail (old Neovim or missing fd), setup returns early and not all features are available.

---

### vs.python()
- Signature: `vs.python()` -> `string | nil`
- Returns: Absolute path to the currently selected Python interpreter (e.g. `/home/user/.venv/bin/python`) or `nil` if no venv is selected.
- Purpose: Use when you need the interpreter binary (to spawn processes, tools, linters, etc.).
- Example:
```lua
local py = require("venv-selector").python()
if py then
  vim.notify("Active python: " .. py)
else
  vim.notify("No active venv")
end
```

---

### vs.venv()
- Signature: `vs.venv()` -> `string | nil`
- Returns: Absolute path to the virtualenv root directory (folder containing `bin/` or `Scripts/`) or `nil`.
- Purpose: Useful for statuslines, diagnostics, or inspecting files inside the venv.
- Example:
```lua
local venv_path = require("venv-selector").venv()
if venv_path then
  print("Venv root:", venv_path)
end
```

---

### vs.source()
- Signature: `vs.source()` -> `string | nil`
- Returns: Name of the search that discovered the currently selected venv (e.g. `"poetry"`, `"cwd"`, `"pyenv"`), or `nil`.
- Purpose: Helpful when callbacks or automation should behave differently depending on how the venv was found.
- Example:
```lua
local src = require("venv-selector").source()
if src == "poetry" then
  -- special-case logic for poetry projects
end
```

---

### vs.workspace_paths()
- Signature: `vs.workspace_paths()` -> `string[]`
- Returns: Array of workspace root strings detected via LSP for the current buffer/project.
- Purpose: Use when constructing searches that reference workspace roots (e.g. templates using `$WORKSPACE_PATH`).
- Notes:
  - This depends on LSP clients being attached. If no LSP is active, an empty array may be returned.

---

### vs.cwd()
- Signature: `vs.cwd()` -> `string`
- Returns: Current Neovim working directory (equivalent to `vim.fn.getcwd()`).
- Purpose: Useful in custom search templates or for status displays.

---

### vs.file_dir()
- Signature: `vs.file_dir()` -> `string | nil`
- Returns: Directory of the current buffer's file (or `nil` when buffer has no file).
- Purpose: Useful for file-local searches that use `$FILE_DIR`.

---

### vs.activate_from_path(python_path, env_type?)
- Signature: `vs.activate_from_path(python_path, env_type?)`
- Parameters:
  - `python_path` (string) — Full path to a Python interpreter (typically a venv's `bin/python` or `Scripts\python.exe`).
  - `env_type` (optional string) — One of `"venv" | "conda" | "uv"`. If omitted, the plugin attempts to infer the type.
- Purpose: Programmatically activate a virtual environment by passing the interpreter path directly (bypasses the interactive picker).
- Important:
  - This is intended for virtualenv-like interpreters. Passing a system Python or an unrelated interpreter may result in incorrect environment variable settings (for example, setting `VIRTUAL_ENV` for a non-venv path).
  - Use `env_type` when activating conda-style environments so the plugin sets `CONDA_PREFIX` instead of `VIRTUAL_ENV`.
- Example:
```lua
require("venv-selector").activate_from_path("/home/you/.local/share/venvs/myproject/bin/python", "venv")
```

---

### vs.deactivate()
- Signature: `vs.deactivate()`
- Purpose: Programmatically deactivate the active virtual environment for the current buffer:
  - Prevents automatic restoration on BufEnter for that buffer.
  - Stops plugin-owned Python LSP clients attached to the buffer.
  - Restores baseline LSP settings for the buffer.
  - Removes environment variables and PATH modifications applied by the plugin.
- Example:
```lua
require("venv-selector").deactivate()
```
- Notes:
  - Deactivation tries to leave the LSP configuration in a sensible baseline state; if you rely on custom LSP client configs, you may need to re-attach / restart those clients yourself.

---

### vs.stop_lsp_servers()
- Signature: `vs.stop_lsp_servers()`
- Purpose: Stop plugin-managed Python LSP clients for the current buffer. Useful if you changed interpreter settings and want a clean restart of LSP clients.
- Example:
```lua
require("venv-selector").stop_lsp_servers()
```
- Notes:
  - This stops only LSP clients the plugin owns/managed. It does not forcibly stop unrelated non-python LSPs.

---

## 📝 Notes & types

- `env_type` accepted values:
  - `"venv"` — venv / virtualenv style.
  - `"conda"` — Anaconda / Miniconda style.
  - `"uv"` — PEP-723 (`uv`) style environments.
- Interpreter path normalization:
  - On Unix: interpreter typically at `.../bin/python`
  - On Windows: interpreter typically at `...\\Scripts\\python.exe`
- LSP work:
  - The plugin attempts to avoid race conditions when restarting LSP servers (a gated restart flow is used).
  - `workspace_paths()` relies on attached LSP clients for accurate results.

---

## 💡 Examples

- Programmatic activation + restart LSP:
```lua
local vs = require("venv-selector")
vs.activate_from_path("/home/me/.venvs/myproject/bin/python", "venv")
-- Optionally stop plugin LSPs to force a restart:
vs.stop_lsp_servers()
```

- Use Python path for a debug adapter or external tool:
```lua
local py = require("venv-selector").python()
if py then
  -- pass to debug adapter settings or spawn a job
  print("Debugger should use:", py)
end
```

---

## 🔗 See also
- `:VenvSelect` — interactive picker (user-facing).
- `:VenvSelectLog` — log output for debugging when `log_level` is `DEBUG`/`TRACE`.
- `docs/OPTIONS.md` — configuration options and defaults.
- `docs/USAGE.md` — usage guides and examples.

---

If you'd like, I can:
- Apply this exact file content to `docs/API.md`.
- Generate small snippet examples for common integrations (statusline, nvim-dap config).
- Add a "changelog" subsection showing when API additions occurred.