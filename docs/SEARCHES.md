# Usage — venv-selector.nvim

This document provides actionable installation steps, examples, and troubleshooting for `venv-selector.nvim`. The top-level README is an index that links to this file and other documentation in `docs/`.

## Table of contents

- [Searches: default behavior and custom searches](#searches-default-behavior-and-custom-searches)
  - [Example: add a custom search](#example-add-a-custom-search)
  - [Override or disable default searches](#override-or-disable-default-searches)
- [Special notes (Anaconda/Miniconda, UV PEP-723)](#special-notes-anacondaminiconda-uv-pep-723)
- [Performance tips](#performance-tips)
- [Callbacks](#callbacks)
  - [on_telescope_result_callback](#on_telescope_result_callback)
  - [on_venv_activate_callback](#on_venv_activate_callback)
- [Statusline integrations](#statusline-integrations)
- [Troubleshooting](#troubleshooting)
- [Where to find more examples and reference](#where-to-find-more-examples-and-reference)

---

## Searches: default behavior and custom searches

The plugin runs a set of "searches" to discover Python interpreter binaries. Defaults are provided for common venv managers and locations; the search templates are defined in `lua/venv-selector/config.lua`.

You can add or override searches in your plugin configuration using the top-level `search` table.

Special search variables available in commands:

- `$CWD` — Neovim current working directory
- `$WORKSPACE_PATH` — workspace roots reported by LSP
- `$FILE_DIR` — directory of the current buffer
- `$CURRENT_FILE` — absolute path to the current buffer file

### Example: add a custom search

If your venvs live in `~/Code`, add:

```lua
{
  search = {
    my_venvs = {
      command = "fd '/bin/python$' ~/Code --full-path -a -L",
    },
  },
}
```

Notes:

- Use `python.exe$` on Windows where executables end with `.exe`.
- Shell quoting rules vary: `fish` often requires quoting regexes (e.g. `'/bin/python$'`). Test in your environment.

### Override or disable default searches

- Override: define a `search` entry with the same name to replace the default.
- Disable a specific default search: set it to `false`.
- Disable all built-in searches: set `options.enable_default_searches = false`.

```lua
{
  options = { enable_default_searches = false },
  search = {
    custom = { command = "fd /bin/python$ ~/Programming/Python --full-path -a -L" },
  }
}
```

---

## Special notes (Anaconda/Miniconda, UV PEP-723)

### Anaconda / Miniconda

When creating a custom search that finds conda/anaconda interpreters, set `type = "anaconda"` for that search. This ensures the plugin sets `CONDA_PREFIX` and other conda-specific environment variables.

```lua
{
  search = {
    anaconda_local = {
      command = "fd /python$ /opt/anaconda/bin --full-path --color never -E /proc",
      type = "anaconda",
    }
  }
}
```

### UV PEP-723 script support

The `uv_script` search runs `uv python find --script '$CURRENT_FILE'` when the current file contains inline PEP-723 metadata and shows the resolved interpreter in the picker.

Example PEP-723 script header (for reference):

```python
#!/usr/bin/env python3
# /// script
# dependencies = [
#   "requests",
#   "rich",
# ]
# ///
```

---

## Performance tips

Search speed depends on the `fd` command and flags. To improve performance:

- Narrow the search scope (e.g., search `~/Code` instead of `~`).
- Avoid `-H` (hidden) unless you need to detect dot-prefixed venvs.
- Use `-I` instead of `-HI` if you want to include files ignored by `.gitignore`, etc.
- Disable default searches you don't need and add targeted ones.

Example `fd` usage:

```sh
fd '/bin/python$' $CWD --full-path --color never -E /proc -I -a -L
```

Common flags:

- `-I` / `--no-ignore`
- `-L` / `--follow`
- `-H` / `--hidden`
- `-E` / `--exclude`

---

## Callbacks

The plugin supports callbacks to customize displayed results and to run code on activation.

### on_telescope_result_callback

Use this to modify the displayed string for each result in the picker (useful to shorten long interpreter paths).

Example (shorten display):

```lua
-- In your opts:
local function shorter_name(filename)
  return filename:gsub(os.getenv("HOME"), "~"):gsub("/bin/python", "")
end

opts = {
  options = {
    on_telescope_result_callback = shorter_name,
  },
}
```

You can also use the helper in `examples/statusline.lua`.

### on_venv_activate_callback

Run custom logic when a venv activates (e.g., instruct `poetry` to use the selected Python in a newly opened terminal).

Example pattern — use the robust helpers in `examples/callbacks.lua` for production use:

```lua
opts = {
  options = {
    on_venv_activate_callback = function()
      local command_run = false
      local function run_shell_command()
        local source = require("venv-selector").source()
        local python = require("venv-selector").python()
        if source == "poetry" and not command_run then
          local cmd = "poetry env use " .. vim.fn.shellescape(python) .. "\n"
          vim.api.nvim_feedkeys(cmd, "n", false)
          command_run = true
        end
      end
      vim.api.nvim_create_augroup("VenvSelectorTerminalCommands", { clear = true })
      vim.api.nvim_create_autocmd("TermEnter", {
        group = "VenvSelectorTerminalCommands",
        pattern = "*",
        callback = run_shell_command,
      })
    end
  }
}
```

---

## Statusline integrations

The plugin exposes `options.statusline_func` for integrating with `lualine` and `nvchad`. See `examples/statusline.lua` for ready-to-use functions.

Example lualine snippet:

```lua
options = {
  statusline_func = {
    lualine = function()
      local venv_path = require("venv-selector").venv()
      if not venv_path or venv_path == "" then return "" end
      local venv_name = vim.fn.fnamemodify(venv_path, ":t")
      return "🐍 " .. (venv_name or "") .. " "
    end,
  },
}
```

---

## Troubleshooting

### My venvs don't show up

- Add a custom search targeting where your venvs live.
- Ensure your `fd` regex matches the interpreter name (e.g., `python$` vs `python.exe$`).
- If relying on `$WORKSPACE_PATH`, ensure LSP has attached.

### VenvSelect is slow

- Restrict `fd` scope, avoid unnecessary `-H`, and disable unused default searches.

### Conda environments behave oddly

- Make sure searches returning conda envs include `type = "anaconda"`.

---

## Where to find more examples and reference

- Configuration reference: `docs/OPTIONS.md`
- Public API: `docs/API.md`
- Examples: `examples/` (`statusline.lua`, `callbacks.lua`)
- Changelog & releases: `CHANGELOG.md`
- Default search templates: `lua/venv-selector/config.lua`

---
