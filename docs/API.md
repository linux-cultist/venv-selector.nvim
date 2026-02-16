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
- Detailed API
- Examples

<br>

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

<br>

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

<br>

### vs.python()
- Signature: `vs.python()` -> `string | nil`
- Returns: Absolute path to the active python interpreter for the workspace/project. Returns `nil` if no python interpreter has been set active (by the plugin).
- Purpose: Use when you need the path to the interpreter binary.
- Example:
```lua
local py = require("venv-selector").python()
if py then
  vim.notify("Active python path: " .. py)
else
  vim.notify("No python is activated by the plugin.")
end
```

<br>

### vs.venv()
- Signature: `vs.venv()` -> `string | nil`
- Returns: Absolute path to the active virtual environment folder (containing `bin/` or `Scripts/`) or `nil` if no venv has been set active (by the plugin)
- Purpose: Useful for statuslines, diagnostics, or inspecting files inside the venv.
- Example:
```lua
local venv_path = require("venv-selector").venv()
if venv_path then
  print("Virtual environment is located at: ", venv_path)
end
```

<br>

### vs.source()
- Signature: `vs.source()` -> `string | nil`
- Returns: Name of the search that discovered the currently selected venv (e.g. `"poetry"`, `"cwd"`, `"pyenv"`), or `nil` if no interpreter has been set active (by the plugin)
- Purpose: Helpful when callbacks or automation should behave differently depending on how the venv was found.
- Example:
```lua
local src = require("venv-selector").source()
if src == "poetry" then
  -- special-case logic for poetry projects
end
```
<br>

### vs.workspace_paths()
- Signature: `vs.workspace_paths()` -> `string[]`
- Returns: Array of workspace root strings detected via LSP for the current workspace/project in the active buffer.
- Purpose: Use when constructing searches that reference workspace roots (e.g. templates using `$WORKSPACE_PATH`).
- Notes:
  - If no LSP is active or the LSP cant detect a workspace, an empty array is returned.

<br>

### vs.cwd()
- Signature: `vs.cwd()` -> `string`
- Returns: Current Neovim working directory (equivalent to `vim.fn.getcwd()`). Usually the directory where you start neovim from, but can be changed.
- Purpose: Useful in custom search templates or for status displays.

<br>

### vs.file_dir()
- Signature: `vs.file_dir()` -> `string | nil`
- Returns: Directory of the current buffer's file (or `nil` when buffer has no file).
- Purpose: Useful for file-local searches that use `$FILE_DIR`.

<br>

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

<br>

### vs.deactivate()
- Signature: `vs.deactivate()`
- Purpose: Programmatically deactivate the active virtual environment for the current buffer:
  - Prevents automatic restoration on BufEnter for that buffer.
  - Stops Python LSP clients that were started or modified by venv-selector.
  - Restarts Python LSP clients using the previously snapshotted baseline configuration.
  - Removes environment variables and PATH modifications applied by the plugin.
  - Clears internal activation state so the same environment can be reactivated immediately.
- Example:
```lua
require("venv-selector").deactivate()
```
- Notes:
  - Deactivation restores the LSP configuration to the snapshotted baseline taken before venv-selector modified the client.
  - Because Neovim LSP clients cannot be mutated in place, deactivation stops plugin-managed clients and restarts them using the stored baseline config.
  - If other plugins or user code dynamically alter LSP client configuration after the snapshot was taken, those changes will not automatically be re-applied.
  - In highly customized LSP setups, you may still need to manually re-attach or restart clients to fully restore your desired configuration.

<br>

### vs.stop_lsp_servers()
- Purpose: Stop Python LSP clients that were started or modified by venv-selector for the current buffer.
- This is useful when you want to force a clean LSP restart while keeping the currently active virtual environment.
- Example:
```lua
require("venv-selector").stop_lsp_servers()
```
- Notes:
  - Only plugin-managed Python LSP clients attached to the current buffer are stopped.
  - Python LSP clients attached exclusively to other buffers are not affected.
  - Unrelated non-Python LSP clients are not affected.
- This does not:
  - Restore baseline LSP configuration
  - Clear the active virtual environment state
  - Remove environment variables or PATH modifications
  - Prevent automatic re-activation
- After stopping plugin-managed clients, configured hooks are also invoked with (nil, nil, bufnr) to allow user-supplied hooks to perform additional cleanup if they implement that convention.
  - After calling this function, LSP clients will remain stopped until:
  - The environment is reactivated, or
  - Some other mechanism restarts the Python LSP clients.
---

## 💡 Examples

### Activate a virtual environment programmatically

```lua
local vs = require("venv-selector")
vs.activate_from_path("/home/me/.venvs/myproject/bin/python", "venv")
```

This:
  - Activates the environment
  - Restarts Python LSP clients with venv-aware settings
  - Updates PATH / environment variables


### Force a clean LSP restart (keep environment active)

```lua
local vs = require("venv-selector")

-- Stop only plugin-managed Python LSP clients
vs.stop_lsp_servers()

-- They can then be restarted by re-activating or via normal lifecycle
vs.activate_from_path(vs.python(), "venv")
```

Use this when:
  - You changed interpreter-related settings
  - You want a clean LSP restart
  - You do NOT want to deactivate the environment

This does not:
  - Clear active environment state
  - Remove PATH / VIRTUAL_ENV
  - Restore baseline LSP configuration


### Fully deactivate the environment

```lua
local vs = require("venv-selector")

vs.deactivate()
```

This:
- Stops plugin-managed Python LSP clients
- Restores baseline LSP configuration
- Clears activation state
- Removes PATH / environment modifications
- Prevents automatic restoration for that buffer

Use this when you want to completely revert to the pre-activation state.

### Use the active Python path for external tools

```lua
local py = require("venv-selector").python()

if py then
  print("Debugger should use:", py)
end
```

---
