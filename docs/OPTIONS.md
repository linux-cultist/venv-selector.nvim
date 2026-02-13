# ⚙️ venv-selector.nvim — Options reference

This document lists plugin options grouped by topic. Each option includes a short description and a ready-to-copy Lua snippet. The default value and type are provided as a comment in the Lua snippet so you can paste it directly into your config.

Use these options inside your plugin configuration, for example:
```/dev/null/usage-quickstart.lua#L1-4
options = {
  -- set plugin options here
}
```

---

<details>
<summary>🔎 Search & discovery options</summary>

🔸 `enable_default_searches`  
Enable or disable the built-in packaged searches. Set to `false` to provide your own `search` table.

```lua
-- default: true (boolean)
options = { enable_default_searches = false }
```

🔸 `search_timeout`  
Timeout in seconds to stop an individual search command if it runs too long.

```lua
-- default: 5 (number)
options = { search_timeout = 8 }
```

🔸 `fd_binary_name`  
Force which `fd` binary to call (e.g. `"fd"` or `"fdfind"`). Useful for distributions with different binary names.

```lua
-- default: auto-detected (string)
options = { fd_binary_name = "fdfind" }
```

🔸 `picker_icons`  
Map of icons to show per venv/search type in pickers. Example: `{ poetry = "📝", hatch = "🔨", default = "🐍" }`.

```lua
-- default: {} (table)
options = { picker_icons = { poetry = "📝", default = "🐍" } }
```

</details>

---

<details>
<summary>🗃️ Cache & workspace activation</summary>

🔸 `enable_cached_venvs`  
Save & re-apply the last-selected venv per workspace.

```lua
-- default: true (boolean)
options = { enable_cached_venvs = true }
```

🔸 `cached_venv_automatic_activation`  
If `false`, cached venvs won't activate automatically; use `:VenvSelectCached` to apply them manually.

```lua
-- default: true (boolean)
options = { cached_venv_automatic_activation = false }
```

🔸 `cache.file` (advanced)  
Path to the on-disk cache file (advanced override).

```lua
-- default: "~/.cache/venv-selector/venvs2.json" (string)
-- advanced / not commonly needed
options = {}
settings = { cache = { file = vim.fn.expand("~/.cache/my-venv-cache.json") } }
```

</details>

---

<details>
<summary>🖥️ Terminal, environment & shell</summary>

🔸 `activate_venv_in_terminal`  
Attempt to activate the selected venv in terminals spawned from Neovim so new terminals inherit the environment.

```lua
-- default: true (boolean)
options = { activate_venv_in_terminal = true }
```

🔸 `set_environment_variables`  
Whether to set `VIRTUAL_ENV` or `CONDA_PREFIX` when activating a venv.

```lua
-- default: true (boolean)
options = { set_environment_variables = true }
```

🔸 `shell`  
Override the shell and shell flags used when running search commands (useful for Fish or custom shells).

```lua
-- default: { shell = vim.o.shell, shellcmdflag = vim.o.shellcmdflag } (table)
options = { shell = { shell = "/usr/bin/fish", shellcmdflag = "-c" } }
```

</details>

---

<details>
<summary>🧭 Picker & UI options</summary>

🔸 `picker`  
Which picker backend to use: `"telescope"`, `"fzf-lua"`, `"snacks"`, `"native"`, `"mini-pick"`, or `"auto"` (auto-detect).

```lua
-- default: "auto" (string)
options = { picker = "telescope" }
```

🔸 `picker_filter_type`  
Mode for filtering input in pickers: `"substring"` or `"character"`.

```lua
-- default: "substring" (string)
options = { picker_filter_type = "character" }
```

🔸 `selected_venv_marker_icon`  
Icon used in pickers to mark the currently selected venv (emoji or plain text).

```lua
-- default: "✔" (string)
options = { selected_venv_marker_icon = "🐍" }
```

🔸 `selected_venv_marker_color`  
Hex color used for the selected marker in pickers that support color rendering.

```lua
-- default: "#00FF00" (string)
options = { selected_venv_marker_color = "#10B981" }
```

🔸 `picker_columns`  
Define which columns appear and their order in pickers; remove entries to hide columns.

```lua
-- default: { "marker", "search_icon", "search_name", "search_result" } (array)
options = { picker_columns = { "marker", "search_name", "search_result" } }
```

🔸 `picker_options`  
Pass backend-specific options (e.g., `snacks` layout presets).

```lua
-- default: {} (table)
options = { picker_options = { snacks = { layout = { preset = "select" } } } }
```

</details>

---

<details>
<summary>🔔 Notifications & hooks</summary>

🔸 `notify_user_on_venv_activation`  
Show a notification when a venv is activated.

```lua
-- default: false (boolean)
options = { notify_user_on_venv_activation = true }
```

🔸 `override_notify`  
If `true` and `nvim-notify` is installed, use it instead of `vim.notify` for nicer notifications.

```lua
-- default: true (boolean)
options = { override_notify = true }
```

🔸 `on_venv_activate_callback`  
Callback invoked after activation. Receives `(venv_path, env_type)`.

```lua
-- default: nil (function or nil)
options = {
  on_venv_activate_callback = function(venv_path, env_type) print("Activated:", venv_path, env_type) end
}
```

</details>

---

<details>
<summary>🐞 Debugging & advanced</summary>

🔸 `debug`  
Enable verbose plugin logging. Use `:VenvSelectLog` to inspect logs.

```lua
-- default: false (boolean)
options = { debug = true }
```

🔸 `on_telescope_result_callback`  
Transform picker results for display (e.g., shorten paths). Receives raw filename and returns display string.

```lua
-- default: nil (function or nil)
options = { on_telescope_result_callback = function(path) return vim.fn.fnamemodify(path, ":~") end }
```

🔸 `require_lsp_activation`  
Wait for LSP workspace detection before setting environment variables to avoid premature activation.

```lua
-- default: true (boolean)
options = { require_lsp_activation = true }
```

🔸 `statusline_func`  
Provide functions that return status text for supported statusline integrations.

```lua
-- default: { nvchad = nil, lualine = nil } (table)
options = { statusline_func = { lualine = function() return require("venv-selector").get_status() end } }
```

</details>

---

## Quick examples

- Minimal commonly-used tweaks:

```/dev/null/examples/minimal.lua#L1-1
options = { debug = true, picker = "auto", selected_venv_marker_icon = "🐍" }
```

- Disable built-ins and add a custom `fd` search:

```/dev/null/examples/custom_search.lua#L1-3
options = { enable_default_searches = false }
search = { my_project_venvs = { command = "fd '/bin/python$' ~/Code --full-path --color never" } }
```

---

If you'd like, I can:
- Re-group to fewer, higher-level categories (Search / Picker / Notifications / Cache) and collapse each group by default.
- Add a compact "cheat-sheet" at the top listing the 6 most commonly tweaked options.
- Provide ready-to-drop full configs for popular setups (Telescope + lualine, fzf-lua + nvchad, etc.).

Tell me which follow-up you prefer and I will update only the docs accordingly.