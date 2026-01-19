# Usage — venv-selector.nvim

This document contains actionable instructions and examples to get venv-selector.nvim installed, configured, extended, and debugged. The README was trimmed to be an index; this file contains the usage content that used to be inline in the README.

Table of contents
- Quick start
- Install (lazy.nvim example)
- Requirements & optional integrations
- Basic usage
- Searches: default behaviour and custom searches
- Special notes (Anaconda/Miniconda, UV PEP-723)
- Performance tips
- Callbacks: `on_telescope_result_callback` and `on_venv_activate_callback`
- Statusline integrations
- Troubleshooting
- Where to find more examples

Quick start
1. Install the plugin (example below).
2. Ensure `fd` (or compatible binary) is available on your system.
3. Open a Python file, open the picker (default keymap shown in the example), and select a venv to activate.

Install (lazy.nvim example)
If you use `lazy.nvim`, a minimal `lazy` specification to load the plugin when opening Python files:

```venv-selector.nvim/docs/USAGE.md#L1-20
{
  "linux-cultist/venv-selector.nvim",
  dependencies = {
    "neovim/nvim-lspconfig",
    { "nvim-telescope/telescope.nvim", branch = "0.1.x", dependencies = { "nvim-lua/plenary.nvim" } }, -- choose another supported picker if preferred
  },
  ft = "python", -- load when a Python file is opened
  keys = {
    { ",v", "<cmd>VenvSelect<cr>" }, -- open the picker with ',v' (customize as needed)
  },
}
```

Requirements & optional integrations
- Required:
  - Neovim >= 0.11
  - `fd` (or `fdfind`) for the default searches (you may supply custom searches using any command)
  - A "picker" implementation: `telescope`, `fzf-lua`, `snacks`, `mini-pick`, or the native `vim.ui.select`
- Optional:
  - `nvim-dap` / `nvim-dap-python` / `debugpy` for debugger integration
  - `nvim-notify` if you want richer notifications
  - Nerd font for correct icons in some pickers/statuslines

Basic usage
- Open a Python file.
- Trigger the picker (the example keymap above uses `,v`).
- Select a result; the plugin will attempt to activate the venv and (when relevant) update LSP & DAP integrations.

Searches: default behaviour and custom searches
The plugin runs multiple "searches" to find Python interpreters. Default searches look in the workspace, the current working directory, known manager locations (poetry, pyenv, conda/miniconda, pipx, etc.) and the current file. Defaults are defined in `lua/venv-selector/config.lua`.

Special search template variables you can use in custom `fd` commands:
- `$CWD` — Neovim current working directory (where you started Neovim)
- `$WORKSPACE_PATH` — workspace roots reported by LSP (when available)
- `$FILE_DIR` — directory of the currently opened file
- `$CURRENT_FILE` — absolute path of the currently opened file

Create a custom search: example
If your venvs live in `~/Code`, add a search:

```venv-selector.nvim/docs/USAGE.md#L21-40
{
  search = {
    my_venvs = {
      command = "fd python$ ~/Code --full-path -a -L",
    },
  },
}
```

Notes:
- Use `python.exe$` on Windows if the interpreter has `.exe`.
- On `fish`, quote patterns like `'/bin/python$'`. On `bash`/`zsh` quotes are often optional. Powershell quoting behaves differently — test in your environment.

Override or disable default searches
- Override: define a search with the same name (e.g., `workspace`) to replace the default.
- Disable a specific default search: set it to `false`.
- Disable all built-in searches: set `options.enable_default_searches = false`.

```venv-selector.nvim/docs/USAGE.md#L41-60
{
  options = { enable_default_searches = false },
  search = {
    workspace = false,
    custom = { command = "fd /bin/python$ ~/Programming/Python --full-path -a -L" },
  }
}
```

Special notes

Anaconda / Miniconda
- If you create a search for conda/anaconda environments, set `type = "anaconda"` for that search result. The plugin uses the type to determine whether to set `CONDA_PREFIX` and other conda-specific environment variables.

```venv-selector.nvim/docs/USAGE.md#L61-80
{
  search = {
    anaconda_local = {
      command = "fd /python$ /opt/anaconda/bin --full-path --color never -E /proc",
      type = "anaconda",
    }
  }
}
```

UV PEP-723 script support
- The plugin includes `uv` script support. When a script contains PEP-723 inline metadata, the `uv_script` search uses `uv python find --script '$CURRENT_FILE'` to find the appropriate interpreter and will show it in the picker.

Performance tips
- Search speed is determined by your `fd` command and flags.
- If searches are slow, narrow the scope:
  - Avoid `-H` (hidden) unless you're searching `.venv`-style folders that start with a dot.
  - Use path restrictions (search your `~/Code` instead of `~`).
  - Disable default `cwd` search and add a specialized one if you know venv locations.
- Example: `fd '/bin/python$' $CWD --full-path --color never -E /proc -I -a -L` (note: `-I` disables ignore files; `-a` shows hidden results if needed).

Common useful `fd` flags
- `-I` / `--no-ignore` — include things in `.gitignore` / `.fdignore`
- `-L` / `--follow` — follow symlinks
- `-H` / `--hidden` — include dotfiles & hidden dirs
- `-E` / `--exclude` — exclude patterns

Callbacks

1) `on_telescope_result_callback`
- Use this callback to modify how each result is displayed in the telescope/snacks picker.
- Useful to shorten full interpreter paths to a cleaner display string.

Example: shorten path shown in picker (replace home with `~` and drop `/bin/python`)
Use the example helper in `examples/statusline.lua` or write your own. Short example:

```venv-selector.nvim/docs/USAGE.md#L81-100
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

2) `on_venv_activate_callback`
- Run arbitrary code when a venv activates. Useful for running manager-specific commands (e.g., `poetry env use <python>` in a terminal) or setting up terminal autocommands.

Example pattern (see `examples/callbacks.lua` for robust helpers)
- The typical pattern: create an autocommand group and create a `TermEnter` autocmd that will run once and feed the desired command into the terminal.

```venv-selector.nvim/docs/USAGE.md#L101-125
opts = {
  options = {
    on_venv_activate_callback = function()
      local command_run = false
      local function run_shell_command()
        local source = require("venv-selector").source()
        local python = require("venv-selector").python()
        if source == "poetry" and not command_run then
          local cmd = "poetry env use " .. python
          vim.api.nvim_feedkeys(cmd .. "\n", "n", false)
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

Statusline integrations
- The plugin supports custom statusline functions. Use the `options.statusline_func` table and supply `lualine` and/or `nvchad` functions.

Example for `lualine` (short function returning `🐍 <venv_name>`):

```venv-selector.nvim/examples/statusline.lua#L1-28
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

We provide ready-to-use files under `examples/`:
- `examples/statusline.lua` — lualine and nvchad snippets plus `shorter_name`.
- `examples/callbacks.lua` — safe callback helpers and notification utilities.

Troubleshooting

- "My venvs don't show up"
  - Add a custom search that targets the folder where your venvs live.
  - Ensure your `fd` regex matches interpreter names (`python$` vs `python.exe$`).
  - If using workspace-based searches, make sure LSP has been attached so `$WORKSPACE_PATH` is populated.

- "VenvSelect is slow"
  - Narrow your `fd` search scope or disable hidden files (`-I` instead of `-HI`) if you don't need them.
  - Remove unnecessary `-H` if you don't look for dot-prefixed venv folders.
  - Disable any default searches you don't need.

- "Conda environments behave oddly"
  - Ensure searches that discover conda environments set `type = "anaconda"` so the plugin can set `CONDA_PREFIX` and related variables.

Where to find more examples and reference
- Configuration reference: `docs/OPTIONS.md`
- Public API: `docs/API.md`
- Examples directory: `examples/` (statusline + callbacks)
- Changelog & recent news: `CHANGELOG.md`
- The default search definitions live in `lua/venv-selector/config.lua` if you need to inspect or copy the default patterns.

If you want, I can:
- move any remaining inline examples into additional `examples/` files,
- add a small sample `USAGE` image or animated GIF for the README,
- or add more language-specific sample `fd` patterns for different shells/OSes.
