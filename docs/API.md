# 🧩 Public API — venv-selector.nvim

This document is a concise, developer-focused reference for the public API exported by
`require("venv-selector")`. It documents the exposed functions, their signatures,
brief descriptions, return values, usage examples, and important notes/gotchas.

Quick import
```lua
local vs = require("venv-selector")
```

Table of contents
- Quick reference
- Detailed API
- Examples
- Statusline & nvim-dap snippets
- Notes & types
- See also

---

## ⚡ Quick reference

The short table below is a compact summary. Each entry links to the detailed section below.

| Function (signature) | Returns | Short description |
|---|---:|---|
| 🛠️ `vs.setup(conf)` | `nil` | Initialize plugin: validate prerequisites, register autocmds & commands (global). |
| 🐍 `vs.python()` | `string | nil` | Active Python interpreter path for the current buffer/project, or `nil`. |
| 🧰 `vs.venv()` | `string | nil` | Active virtualenv root directory (current buffer/project), or `nil`. |
| 🔎 `vs.source()` | `string | nil` | Name of the search that discovered the active venv for the current buffer (e.g. `"poetry"`), or `nil`. |
| 🧭 `vs.workspace_paths()` | `string[]` | Workspace root folders detected (via LSP) for the active buffer. |
| 📁 `vs.cwd()` | `string` | Neovim current working directory (global). |
| 📂 `vs.file_dir()` | `string | nil` | Directory of the current buffer's file, or `nil` if none. |
| ⚡ `vs.activate_from_path(python_path, env_type?)` | `nil` | Programmatically activate a venv by interpreter path (affects current buffer/project). |
| ⛔ `vs.deactivate()` | `nil` | Deactivate the venv for the current buffer: restore baseline LSP, cleanup env vars/PATH. |
| 🛑 `vs.stop_lsp_servers()` | `nil` | Stop plugin-managed Python LSP clients for the current buffer. |

---

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
- Notes:
  - Call this once from your plugin configuration (e.g. in your lazy.nvim spec `opts` or `setup`).
  - If prerequisites fail (old Neovim, missing `fd`), setup returns early and not all features will be available.

---

<a id="python"></a>
### 🐍 vs.python()
- Signature: `vs.python()` -> `string | nil`
- Returns: Absolute path to the active Python interpreter for the current buffer/project (e.g. `/home/user/.venv/bin/python`), or `nil` if none is active.
- Purpose: Retrieve the interpreter binary path to pass to external tools, debuggers, or job spawns.
- Buffer scope: value is relevant to the currently active buffer; APIs and commands in the plugin track activation per-project/buffer.
- Example:
```lua
local py = require("venv-selector").python()
if py then
  vim.notify("Active python path: " .. py)
else
  vim.notify("No python is activated by the plugin.")
end
```

---

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

---

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

---

<a id="workspace_paths"></a>
### 🧭 vs.workspace_paths()
- Signature: `vs.workspace_paths()` -> `string[]`
- Returns: Array of workspace root strings detected via LSP for the active buffer/project.
- Purpose: Useful when constructing searches that reference workspace roots (templates that use `$WORKSPACE_PATH`).
- Notes:
  - This relies on attached LSP clients. If no LSP is active or no workspace is detected, the function returns an empty array.

---

<a id="cwd"></a>
### 📁 vs.cwd()
- Signature: `vs.cwd()` -> `string`
- Returns: Current Neovim working directory (equivalent to `vim.fn.getcwd()`).
- Purpose: Use in custom search templates or status displays when a global working directory is needed.

---

<a id="file_dir"></a>
### 📂 vs.file_dir()
- Signature: `vs.file_dir()` -> `string | nil`
- Returns: Directory of the current buffer's file (or `nil` if the buffer has no file).
- Purpose: Useful for file-local searches that use `$FILE_DIR` or for context-aware logic specific to the file's location.

---

<a id="activate_from_path"></a>
### ⚡ vs.activate_from_path(python_path, env_type?)
- Signature: `vs.activate_from_path(python_path, env_type?)`
- Parameters:
  - `python_path` (string): Full path to a Python interpreter (typically a venv's `bin/python` or `Scripts\python.exe`).
  - `env_type` (optional string): One of `"venv" | "conda" | "uv"`. If omitted, the plugin attempts to infer the type.
- Purpose: Programmatically activate a virtual environment by passing the interpreter path directly. This bypasses the interactive picker and applies the same activation logic the plugin uses for selected entries.
- Buffer scope: Activation applies to the current buffer/project context (the plugin tracks activation state per project/buffer).
- Important:
  - Intended for virtualenv-like interpreters. Passing a system Python or arbitrary interpreter may lead to incorrect env var behavior (`VIRTUAL_ENV` set incorrectly).
  - Provide `env_type = "conda"` for conda-style environments so the plugin sets `CONDA_PREFIX` instead of `VIRTUAL_ENV`.
- Example:
```lua
require("venv-selector").activate_from_path("/home/you/.local/share/venvs/myproject/bin/python", "venv")
```

---

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
  - Python LSP clients attached exclusively to other buffers are not affected.
  - Unrelated non-Python LSP clients are not affected.
- This does not:
  - Restore baseline LSP configuration
  - Clear the active virtual environment state
  - Remove environment variables or PATH modifications
  - Prevent automatic re-activation
- After stopping plugin-managed clients, configured hooks are also invoked with `(nil, nil, bufnr)` to allow user-supplied hooks to perform additional cleanup if they implement that convention.

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

---

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

---

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

---

### Use the active Python path for external tools
```lua
local py = require("venv-selector").python()
if py then
  print("Debugger should use:", py)
end
```

---

## 🔧 Statusline & nvim-dap snippets

Below are two short, copy-paste-ready snippets that show common integrations.

### Lualine status component (show active venv name)
```lua
-- Add this to your lualine `sections` config (lualine_x or similar)
local function venv_name()
  local vs = require("venv-selector")
  local venv = vs.venv()
  if not venv then
    return ""
  end
  return require("lualine.utils.utils").basename(venv) or venv
end

require('lualine').setup({
  sections = {
    lualine_x = { venv_name, 'encoding', 'fileformat', 'filetype' },
    -- ...
  }
})
```

### NvChad / generic statusline (render function)
```lua
-- Example for nvchad-style module:
local M = {}
function M.render()
  local vs = require("venv-selector")
  local venv = vs.venv()
  if not venv then return "" end
  return "venv: " .. vim.fn.fnamemodify(venv, ":t")
end
return M
```

### nvim-dap configuration using active Python interpreter (debugpy)
```lua
local dap = require('dap')
local vs = require('venv-selector')

dap.adapters.python = {
  type = 'executable';
  command = vs.python() or 'python'; -- prefer active venv python
  args = { '-m', 'debugpy.adapter' };
}

dap.configurations.python = {
  {
    type = 'python';
    request = 'launch';
    name = 'Launch file (venv)';
    program = "${file}";
    pythonPath = function()
      return vs.python() or '/usr/bin/python'
    end;
  },
}
```

Notes:
- If `vs.python()` returns `nil`, fall back to a system `python` or a configured default.
- When using the adapter `command = vs.python()`, ensure the returned interpreter is suitable to run the debug adapter (it should be a Python with debugpy installed).

---