# 🧩 Public API — venv-selector.nvim


Quick import
```lua
local vs = require("venv-selector")
```

<br>


## ⚡ Quick reference

The short table below is a compact summary. Each entry links to the detailed section below.

| Function (signature) | Returns | Short description |
|---|---:|---|
| [🛠️ `vs.setup(conf)`](#setup) | `nil` | Initialize plugin: validate prerequisites, register autocmds & commands (global). |
| [🐍 `vs.python()`](#python) | `string | nil` | Active Python interpreter path for the current buffer/project, or `nil`. |
| [🧰 `vs.venv()`](#venv) | `string | nil` | Active virtualenv root directory (current buffer/project), or `nil`. |
| [🔎 `vs.source()`](#source) | `string | nil` | Name of the search that discovered the active venv for the current buffer (e.g. `"poetry"`), or `nil`. |
| [🧭 `vs.workspace_paths()`](#workspace_paths) | `string[]` | Workspace root folders detected (via LSP) for the active buffer. |
| [📁 `vs.cwd()`](#cwd) | `string` | Neovim current working directory (global). |
| [📂 `vs.file_dir()`](#file_dir) | `string | nil` | Directory of the current buffer's file, or `nil` if none. |
| [⚡ `vs.activate_from_path(python_path, env_type?)`](#activate_from_path) | `nil` | Programmatically activate a venv by interpreter path (affects current buffer/project). |
| [⛔ `vs.deactivate()`](#deactivate) | `nil` | Deactivate the venv for the current buffer: restore baseline LSP, cleanup env vars/PATH. |
| [🛑 `vs.stop_lsp_servers()`](#stop_lsp_servers) | `nil` | Stop plugin-managed Python LSP clients for the current buffer. |
| [🔄 `vs.restart_lsp_servers()`](#restart_lsp_servers) | `nil` | Restart plugin-managed Python LSP clients for the current buffer. |

<br>

## 🧾 Detailed API

<a id="setup"></a>
### 🛠️ vs.setup(conf)
- Signature: `vs.setup(conf)`
- Parameters:
  - `conf` (table | nil): Plugin configuration table — see `docs/OPTIONS.md` for the full schema.
- Returns: `nil`
- Purpose: Initialize the plugin. Validates Neovim version and `fd` binary, sets up notifications and highlights, registers autocmds & user commands.
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
Call this once from your plugin configuration (e.g. in your lazy.nvim spec `opts` or `setup`).

<br>

<a id="python"></a>
### 🐍 vs.python()
- Signature: `vs.python()` -> `string | nil`
- Returns: Absolute path to the active Python interpreter for the current buffer/project (e.g. `/home/user/.venv/bin/python`), or `nil` if none is active.
- Purpose: Retrieve the interpreter binary path to pass to external tools, debuggers, or job spawns.
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

<a id="venv"></a>
### 🧰 vs.venv()
- Signature: `vs.venv()` -> `string | nil`
- Returns: Absolute path to the active virtual environment root folder (containing `bin/` or `Scripts/`) for the current buffer/project, or `nil`.
- Purpose: Useful for statuslines, UI displays, or inspecting files inside the venv.
- Example:
```lua
local venv_path = require("venv-selector").venv()
if venv_path then
  print("Virtual environment is located at:", venv_path)
end
```

<br>

<a id="source"></a>
### 🔎 vs.source()
- Signature: `vs.source()` -> `string | nil`
- Returns: Name of the search that discovered the currently selected venv for the active buffer/project (e.g. `"poetry"`, `"cwd"`, `"pyenv"`), or `nil` if not set.
- Purpose: Useful when automation or callbacks need to differentiate behavior depending on how the environment was found.
- Example:
```lua
local src = require("venv-selector").source()
if src == "poetry" then
  -- special-case logic for poetry projects
end
```

<br>

<a id="workspace_paths"></a>
### 🧭 vs.workspace_paths()
- Signature: `vs.workspace_paths()` -> `string[]`
- Returns: Array of workspace root strings detected via LSP for the active buffer/project.
- Purpose: Useful when constructing searches that reference workspace roots (templates that use `$WORKSPACE_PATH`).
- Notes:
  - This relies on attached LSP clients. If no LSP is active or no workspace is detected, the function returns an empty array.

<br>

<a id="cwd"></a>
### 📁 vs.cwd()
- Signature: `vs.cwd()` -> `string`
- Returns: Current Neovim working directory (equivalent to `vim.fn.getcwd()`).
- Purpose: Use in custom search templates or status displays when a global working directory is needed.

<br>

<a id="file_dir"></a>
### 📂 vs.file_dir()
- Signature: `vs.file_dir()` -> `string | nil`
- Returns: Directory of the current buffer's file (or `nil` if the buffer has no file).
- Purpose: Useful for file-local searches that use `$FILE_DIR` or for context-aware logic specific to the file's location.

<br>

<a id="activate_from_path"></a>
### ⚡ vs.activate_from_path(python_path, env_type?)
- Signature: `vs.activate_from_path(python_path, env_type?)`
- Parameters:
  - `python_path` (string): Full path to a Python interpreter (typically a venv's `bin/python` or `Scripts\python.exe`).
  - `env_type` (optional string): One of `"venv" | "anaconda". Defaults to "venv".
- Purpose: Programmatically activate a virtual environment by passing the interpreter path directly. This bypasses the interactive picker and applies the same activation logic the plugin uses for selected entries.
- Buffer scope: Activation applies to the current buffer/project context (the plugin tracks activation state per project/buffer).
- Important:
  - Intended for virtualenv-like interpreters. Passing a system Python or arbitrary interpreter may lead to incorrect env var behavior (`VIRTUAL_ENV` set incorrectly).
  - Provide `env_type = "anaconda"` for conda-style environments so the plugin sets `CONDA_PREFIX` instead of `VIRTUAL_ENV`.
- Example:
```lua
require("venv-selector").activate_from_path("/home/you/.local/share/venvs/myproject/bin/python", "venv")
```

<br>

<a id="deactivate"></a>
### ⛔ vs.deactivate()
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

<a id="stop_lsp_servers"></a>
### 🛑 vs.stop_lsp_servers()
- Signature: `vs.stop_lsp_servers()`
- Purpose: Stop Python LSP clients that were started or modified by venv-selector for the current buffer.
- This is useful when you want to force a clean LSP restart while keeping the currently active virtual environment.
- Example:
```lua
require("venv-selector").stop_lsp_servers()
```
- Notes:
  - Only plugin-managed Python LSP clients attached to the current buffer are stopped.
  - It doesnt stop lsp servers that are not activated by the plugin. So before activating a venv, this function doesnt do anything.
  - Python LSP clients attached exclusively to other buffers are not affected.
  - Unrelated non-Python LSP clients are not affected.
  - If it stops the only Python LSP clients running, activate_from_path() or the picker will will not restart anything until LSP clients are started again (e.g. :LspStart, reopening buffer, or whatever starts them in your setup).
- This does not:
  - Restore baseline LSP configuration
  - Clear the active virtual environment state
  - Remove environment variables or PATH modifications
  - Prevent automatic re-activation
- After stopping plugin-managed clients, configured hooks are also invoked with `(nil, nil, bufnr)` to allow user-supplied hooks to perform additional cleanup if they implement that convention.

<br>
    
<a id="restart_lsp_servers"></a>
### 🔄 vs.restart_lsp_servers()

Signature: vs.restart_lsp_servers()
Purpose: Force a clean restart of plugin-managed Python LSP clients for the current buffer while keeping the currently active virtual environment.
Example:
```lua
local vs = require("venv-selector")

-- Force Python LSP to restart using the currently active interpreter
vs.restart_lsp_servers()
```

- Notes:

- Only plugin-managed Python LSP clients attached to the current buffer are restarted.
- The active virtual environment remains unchanged.
- Environment variables and PATH modifications are preserved.
- This is useful when:
  - You installed or removed Python packages.
  - You modified interpreter-related configuration.
  - LSP diagnostics appear stale or inconsistent.
- If no plugin-managed Python LSP clients exist for the current buffer (for example, before any activation), this function is a no-op.
- Unrelated non-Python LSP clients are not affected.



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

<br>

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

<br>

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

<br>

### Use the active Python path for external tools
```lua
local py = require("venv-selector").python()
if py then
  print("Debugger should use:", py)
end
```

<br>

<br>