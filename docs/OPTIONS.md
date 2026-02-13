# ⚙️ Options of venv-selector.nvim

## 🔧 How options are applied

Options are passed via your plugin configuration. Example location for `lazy.nvim`:

```lua
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

Key | Default | Type | Description
--- | --- | --- | ---
`on_venv_activate_callback` | `nil` | function or nil | Callback invoked after a venv activates. Useful to run autocommands or custom shell commands after activation.
`enable_default_searches` | `true` | boolean | Enable/disable built-in default searches. Set to `false` to disable all built-in searches; or override individual searches in `search`.
`enable_cached_venvs` | `true` | boolean | Use cached venvs that are reactivated automatically for known working directories.
`cached_venv_automatic_activation` | `true` | boolean | If `false`, cached venvs won't activate automatically; the `VenvSelectCached` command can be used to activate them manually.
`activate_venv_in_terminal` | `true` | boolean | If `true`, the plugin attempts to activate the selected interpreter inside terminals created from Neovim.
`set_environment_variables` | `true` | boolean | Control whether the plugin sets environment variables like `VIRTUAL_ENV` or `CONDA_PREFIX` when activating a venv.
`notify_user_on_venv_activation` | `false` | boolean | Display a notification when a venv is activated.
`override_notify` | `true` | boolean | If `true` use `nvim-notify` (if installed) for notifications; otherwise use default `vim.notify`.
`search_timeout` | `5` | number (seconds) | Timeout for individual search commands. If a search takes longer, it will be stopped.
`debug` | `false` | boolean | Enable debug logging; when true you can use `:VenvSelectLog` to inspect debug output.
`fd_binary_name` | `M.find_fd_command_name()` | string | The executable name used to run `fd`. Automatically detects `fd` or `fdfind`, override if needed.
`require_lsp_activation` | `true` | boolean | If `true`, plugin waits for LSP workspace detection before setting environment variables.
`shell` | `{ shell = vim.o.shell, shellcmdflag = vim.o.shellcmdflag }` | table | Override the shell and shell flags used when running search commands.
`on_telescope_result_callback` | `nil` | function or nil | Callback used to transform/format each search result shown in the picker. Receives the raw filename and should return a display string.
`picker_filter_type` | `"substring"` | string (`"substring"` or `"character"`) | How picker input filters results.
`selected_venv_marker_color` | `"#00FF00"` | string | Hex color used for the selected venv marker in pickers that support colors.
`selected_venv_marker_icon` | `"✔"` | string | Icon used to mark the selected venv in pickers.
`picker_icons` | `{}` | table | Map of icons per venv type, e.g. `{ poetry = "📝", hatch = "🔨", default = "🐍" }`.
`picker_columns` | `{ "marker", "search_icon", "search_name", "search_result" }` | array | Column order in pickers; omit columns to hide them.
`picker_options` | `{}` | table | Picker-specific options (currently used by some pickers like snacks). Format varies by picker.
`picker` | `"auto"` | string | Default picker to use: `"telescope"`, `"fzf-lua"`, `"snacks"`, `"native"`, `"mini-pick"`, or `"auto"`.
`statusline_func` | `{ nvchad = nil, lualine = nil }` | table | Functions to customize statusline output. Provide `nvchad` and/or `lualine` keys with functions returning a string to display.

---

## 💡 Examples

Minimal: change the selected marker and enable debug:

```lua
{
  options = {
    selected_venv_marker_icon = "🐍",
    debug = true,
  }
}
```

Customizing shell used for searches:

```lua
{
  options = {
    shell = { shell = "/usr/bin/fish", shellcmdflag = "-c" }
  }
}
```

Disabling a single default search (example: disable `workspace` search) — configure the top-level `search` table:

```lua
{
  options = {},
  search = {
    workspace = false,
  }
}
```

Disable all built-in searches:

```lua
{
  options = {
    enable_default_searches = false
  },
}
```

---
