# ⚙️ Options of venv-selector.nvim

## 🔧 How options are applied

Options are passed via your plugin configuration. Example location for `lazy.nvim`:

```/dev/null/lazy-example.lua#L1-12
{
  "linux-cultist/venv-selector.nvim",
  opts = {
    options = {
      -- your plugin options here
    },
    -- optional: add or override searches here
    search = { }
  }
}
```

---

## 🧭 Global options reference

Below each option is listed with its default value and type inline in the description for easier scanning. Use these in `require("venv-selector").setup({ options = { ... }, search = { ... } })`.

### `on_venv_activate_callback`
- Default: `nil` | Type: function or nil  
Callback invoked after a venv activates. Useful to run autocommands, update statuslines or run custom shell commands after activation.

### `enable_default_searches`
- Default: `true` | Type: boolean  
Enable/disable all built-in default searches. Set to `false` to disable the packaged searches and provide your own `search` table instead.

### `enable_cached_venvs`
- Default: `true` | Type: boolean  
Use cached venvs that are reactivated automatically for known working directories.

### `cached_venv_automatic_activation`
- Default: `true` | Type: boolean  
If `false`, cached venvs won't activate automatically; use the `:VenvSelectCached` command to manually activate cached entries.

### `activate_venv_in_terminal`
- Default: `true` | Type: boolean  
When `true`, the plugin attempts to activate the selected interpreter inside terminals created from Neovim so new terminals inherit the venv.

### `set_environment_variables`
- Default: `true` | Type: boolean  
Controls whether the plugin sets environment variables like `VIRTUAL_ENV` or `CONDA_PREFIX` when activating a venv.

### `notify_user_on_venv_activation`
- Default: `false` | Type: boolean  
If `true`, show a user notification when a venv is activated.

### `override_notify`
- Default: `true` | Type: boolean  
If `true`, and `nvim-notify` is installed, the plugin will use it; otherwise it falls back to `vim.notify`.

### `search_timeout`
- Default: `5` | Type: number (seconds)  
Timeout (seconds) for individual search commands. Searches exceeding this duration will be stopped.

### `debug`
- Default: `false` | Type: boolean  
Enable debug logging. When `true` you can use `:VenvSelectLog` to inspect verbose plugin output.

### `fd_binary_name`
- Default: result of `M.find_fd_command_name()` | Type: string  
Executable name used to run `fd` (`fd`, `fdfind`, etc.). Auto-detected by default; override to force a specific binary.

### `require_lsp_activation`
- Default: `true` | Type: boolean  
If `true`, the plugin waits for LSP workspace detection before setting environment variables (helps avoid activating wrong interpreter early).

### `shell`
- Default: `{ shell = vim.o.shell, shellcmdflag = vim.o.shellcmdflag }` | Type: table  
Override the shell and shell flags used when running search commands. Example: `{ shell = "/usr/bin/fish", shellcmdflag = "-c" }`.

### `on_telescope_result_callback`
- Default: `nil` | Type: function or nil  
Callback used to transform/format each search result shown in pickers like Telescope. Receives the raw filename and should return a display string.

### `picker_filter_type`
- Default: `"substring"` | Type: string (`"substring"` or `"character"`)  
How picker input filters results. Use `"substring"` for normal substring matching or `"character"` for character-scoped filtering.

### `selected_venv_marker_color`
- Default: `"#00FF00"` | Type: string  
Hex color used for the selected venv marker in pickers that support color rendering.

### `selected_venv_marker_icon`
- Default: `"✔"` | Type: string  
Icon used to mark the selected venv in pickers. Can be emoji or plain text.

### `picker_icons`
- Default: `{}` | Type: table  
Map of icons per venv type, e.g. `{ poetry = "📝", hatch = "🔨", default = "🐍" }`. Use this to customize per-search icons shown in pickers.

### `picker_columns`
- Default: `{ "marker", "search_icon", "search_name", "search_result" }` | Type: array  
Column order in pickers; omit entries to hide columns. Columns control the picker's displayed fields.

### `picker_options`
- Default: `{}` | Type: table  
Picker-specific options (used by some backends like `snacks`). Format varies by picker — see the picker's docs for details.

### `picker`
- Default: `"auto"` | Type: string  
Default picker to use. Options: `"telescope"`, `"fzf-lua"`, `"snacks"`, `"native"`, `"mini-pick"`, or `"auto"` (auto-detect).

### `statusline_func`
- Default: `{ nvchad = nil, lualine = nil }` | Type: table  
Functions to customize statusline output. Provide `nvchad` and/or `lualine` keys with functions returning a string to display in the statusline.

---

## 💡 Examples

Minimal: change the selected marker and enable debug:

```/dev/null/example1.lua#L1-8
{
  options = {
    selected_venv_marker_icon = "🐍",
    debug = true,
  }
}
```

Customizing the shell used for searches:

```/dev/null/example2.lua#L1-6
{
  options = {
    shell = { shell = "/usr/bin/fish", shellcmdflag = "-c" }
  }
}
```

Disable a single built-in search (example: disable `workspace`):

```/dev/null/example3.lua#L1-8
{
  options = {},
  search = {
    workspace = false
  }
}
```

Disable all built-in searches and provide your own:

```/dev/null/example4.lua#L1-10
{
  options = { enable_default_searches = false },
  search = {
    my_project_venvs = {
      command = "fd '/bin/python$' ~/Code --full-path --color never"
    }
  }
}
```

---

## 📝 Notes and best practices

- Conda/anaconda: If you rely on conda-style environments, set your search entries to return `type = "anaconda"` so the plugin sets `CONDA_PREFIX` and other conda-specific variables correctly.
- fd dependency: The plugin prefers `fd` (or `fdfind`) for default searches. If `fd` is not available on the user's system, provide alternative `search` entries (for example using `find` or a small custom script).
- System Python caution: Be careful when calling activation helpers (e.g., `activate_from_path`) with the system Python path — these functions expect a venv path and may set environment variables incorrectly if used with a system-wide interpreter.
- Performance: For very fast searches, limit the scope of your `fd` queries (avoid searching the entire home directory unless necessary; use `-HI`/directory arguments to narrow).
- Defaults & code: For the annotated defaults and behavior, see `lua/venv-selector/config.lua` — the file contains the canonical defaults and search definitions.

If you'd like, I can:
- Group options into topical subsections (Search, Cache, UI, Debug, Picker) with icons for even clearer structure.
- Add a compact "cheat-sheet" with the 6 most commonly tweaked options at the top.
- Convert this list into a collapsible reference (so readers can expand only the sections they want).

Tell me which follow-up you'd like and I'll update only the docs accordingly.