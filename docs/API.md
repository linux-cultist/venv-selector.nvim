# Public API of venv-selector.nvim

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
