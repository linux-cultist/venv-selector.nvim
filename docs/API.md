# API — venv-selector.nvim

This document describes the public API exported by the plugin. Use these functions in your configuration, statusline integrations, callbacks, or other plugins to inspect and control the selected Python interpreter / virtual environment.

All functions are accessed through:

```lua
require("venv-selector")
```

Note: this file is a concise reference. For configuration options, examples, and deeper behavior, see `docs/OPTIONS.md` and the project README.

---

## Exposed functions

- `require("venv-selector").python()`
  - Returns: absolute path to the selected Python interpreter, or `nil` if none is selected.
  - Purpose: use when you need the Python executable path (for example, to pass to tools or to run commands).
  - Example:
    ```lua
    local python = require("venv-selector").python()
    if python then
      print("Active python:", python)
    else
      print("No venv selected")
    end
    ```

- `require("venv-selector").venv()`
  - Returns: absolute path to the virtual environment root (the venv directory), or `nil` if none is selected.
  - Purpose: use for statusline displays or to inspect the active virtual environment directory.
  - Example (get venv folder name):
    ```lua
    local venv_path = require("venv-selector").venv()
    if venv_path then
      local name = vim.fn.fnamemodify(venv_path, ":t")
      print("Venv:", name)
    end
    ```

- `require("venv-selector").source()`
  - Returns: the name of the search that found the currently selected venv (e.g., `"poetry"`, `"cwd"`, etc.), or `nil` if none.
  - Purpose: useful when writing callbacks that should behave differently depending on which search detected the environment.
  - Example:
    ```lua
    local src = require("venv-selector").source()
    if src == "poetry" then
      -- Run poetry-specific logic
    end
    ```

- `require("venv-selector").workspace_paths()`
  - Returns: a table (array) of workspace directories as detected via LSP for the current buffer/project.
  - Purpose: inspect workspace roots used by default search patterns (examples use `$WORKSPACE_PATH`).
  - Note: workspace detection depends on LSP being attached and active.

- `require("venv-selector").cwd()`
  - Returns: the current working directory (the directory Neovim was started in).
  - Purpose: useful to build custom searches or to show context to the user.

- `require("venv-selector").file_dir()`
  - Returns: the directory of the currently opened buffer/file.
  - Purpose: useful for file-local searches that use `$FILE_DIR` in search templates.

- `require("venv-selector").deactivate()`
  - Purpose: removes the active virtual environment from terminal PATH and unsets any environment variables the plugin sets (for example `VIRTUAL_ENV` or `CONDA_PREFIX`).
  - Use this to programmatically deactivate a venv from within your configuration or scripts.
  - Example:
    ```lua
    require("venv-selector").deactivate()
    ```

- `require("venv-selector").stop_lsp_servers()`
  - Purpose: stops any LSP servers started/managed by the plugin integration. Useful when you want to restart LSP after changing interpreter settings.
  - Example:
    ```lua
    require("venv-selector").stop_lsp_servers()
    ```

- `require("venv-selector").activate_from_path(python_path)`
  - Parameters:
    - `python_path` (string) — absolute path to a Python interpreter (usually the `.../bin/python` inside a virtualenv).
  - Purpose: activate a Python interpreter by providing the path directly (bypasses the picker). This is useful for custom workflows or programmatic activation.
  - Important: This function is intended to activate *virtual environment* interpreter paths only. Trying to activate system Python (or arbitrary interpreters that are not virtual envs) may set environment variables such as `VIRTUAL_ENV` incorrectly because the plugin expects the given path to belong to a virtual environment.
  - Example:
    ```lua
    require("venv-selector").activate_from_path("/home/you/.local/share/virtualenvs/myproject/bin/python")
    ```

---

## Common usage patterns

- Using the API inside a callback (for example `on_venv_activate_callback`) to run project-specific commands:
  ```lua
  options = {
    on_venv_activate_callback = function()
      local source = require("venv-selector").source()
      local python = require("venv-selector").python()
      if source == "poetry" and python then
        -- Example: instruct poetry to use the selected python in a newly opened terminal
        local cmd = "poetry env use " .. vim.fn.shellescape(python) .. "\n"
        vim.api.nvim_feedkeys(cmd, "n", false)
      end
    end
  }
  ```

- Integrating with statuslines (lualine example):
  ```lua
  options = {
    statusline_func = {
      lualine = function()
        local venv_path = require("venv-selector").venv()
        if not venv_path or venv_path == "" then return "" end
        local venv_name = vim.fn.fnamemodify(venv_path, ":t")
        return "🐍 " .. (venv_name or "") .. " "
      end,
    }
  }
  ```

- Programmatic activation flow (example):
  ```lua
  -- programmatically discover a python path by some custom logic and activate it
  local my_python = "/home/user/.virtualenvs/foo/bin/python"
  require("venv-selector").activate_from_path(my_python)
  -- optionally restart/stop LSP servers to ensure they pick up the new interpreter
  require("venv-selector").stop_lsp_servers()
  ```

---

## Best practices and notes

- Many plugin features rely on a working LSP for Python projects. Some searches also use `$WORKSPACE_PATH`, which is populated by LSP. If you expect workspace-based detections, ensure your LSP is attached.
- If you are integrating this API into statuslines or UI code, always handle `nil` returns from `python()`, `venv()`, and `source()` to avoid rendering invalid content.
- Prefer using `activate_from_path` only with interpreter paths you are certain belong to virtual environments. Misuse can result in incorrect environment variables.
- For configuration of searches and options that affect the behavior of these functions, see `docs/OPTIONS.md`. Default search templates and patterns are defined in `lua/venv-selector/config.lua`.

---

If you want, copy example helpers into `examples/` and reference them from your configuration. The `examples/` directory contains statusline and callback helper scripts that demonstrate safe, production-ready usage of these API functions.