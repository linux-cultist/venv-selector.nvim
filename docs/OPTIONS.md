# ⚙️ venv-selector.nvim — Options reference

This document lists plugin options grouped by topic. Each option shows its default value and type inline next to the name. Expand the section you need and copy the short, ready-to-use Lua snippet (shown as `options = { ... }`) into your plugin configuration.

Use these options inside your plugin configuration, for example:
```/dev/null/usage-quickstart.lua#L1-4
options = {
  -- set plugin options here
}
```

---

<details>
<summary>🔎 Search & discovery options</summary>

🔹 `enable_default_searches` (default: `true`, type: boolean)  
Enable or disable the built-in packaged searches. Set to `false` to provide your own `search` table.

```/dev/null/options-examples.lua#L1-1
options = { enable_default_searches = false }
```

🔹 `search_timeout` (default: `5`, type: number)  
Timeout in seconds to stop an individual search command if it runs too long.

```/dev/null/options-examples.lua#L2-2
options = { search_timeout = 8 }
```

🔹 `fd_binary_name` (default: auto-detected, type: string)  
Force which `fd` binary to call (e.g. `"fd"` or `"fdfind"`). Useful for distributions with different binary names.

```/dev/null/options-examples.lua#L3-3
options = { fd_binary_name = "fdfind" }
```

🔹 `picker_icons` (default: `{}`, type: table)  
Map of icons to show per venv/search type in pickers. Example: `{ poetry = "📝", hatch = "🔨", default = "🐍" }`.

```/dev/null/options-examples.lua#L4-4
options = { picker_icons = { poetry = "📝", default = "🐍" } }
```

</details>

---

<details>
<summary>🗃️ Cache & workspace activation</summary>

🔹 `enable_cached_venvs` (default: `true`, type: boolean)  
Enable saving the last-selected venv per workspace and re-applying it automatically when you reopen the workspace.

```/dev/null/options-examples.lua#L5-5
options = { enable_cached_venvs = true }
```

🔹 `cached_venv_automatic_activation` (default: `true`, type: boolean)  
If `false`, cached venvs won't be activated automatically; use `:VenvSelectCached` to activate cached entries manually.

```/dev/null/options-examples.lua#L6-6
options = { cached_venv_automatic_activation = false }
```

🔹 `cache.file` (default: `~/.cache/venv-selector/venvs2.json`, type: string) — advanced  
Path to the on-disk cache file (advanced override).

```/dev/null/options-examples.lua#L7-8
-- advanced override (not commonly needed)
options = {}
settings = { cache = { file = vim.fn.expand("~/.cache/my-venv-cache.json") } }
```

</details>

---

<details>
<summary>🖥️ Terminal, environment & shell</summary>

🔹 `activate_venv_in_terminal` (default: `true`, type: boolean)  
Attempt to activate the selected venv in terminals spawned from Neovim so new terminals inherit the environment.

```/dev/null/options-examples.lua#L9-9
options = { activate_venv_in_terminal = true }
```

🔹 `set_environment_variables` (default: `true`, type: boolean)  
Whether to set `VIRTUAL_ENV` or `CONDA_PREFIX` when activating a venv.

```/dev/null/options-examples.lua#L10-10
options = { set_environment_variables = true }
```

🔹 `shell` (default: `{ shell = vim.o.shell, shellcmdflag = vim.o.shellcmdflag }`, type: table)  
Override the shell and shell flags used when running search commands (useful for Fish or custom shells).

```/dev/null/options-examples.lua#L11-11
options = { shell = { shell = "/usr/bin/fish", shellcmdflag = "-c" } }
```

</details>

---

<details>
<summary>🧭 Picker & UI options</summary>

🔹 `picker` (default: `"auto"`, type: string)  
Which picker backend to use: `"telescope"`, `"fzf-lua"`, `"snacks"`, `"native"`, `"mini-pick"`, or `"auto"` (auto-detect).

```/dev/null/options-examples.lua#L12-12
options = { picker = "telescope" }
```

🔹 `picker_filter_type` (default: `"substring"`, type: string)  
Mode for filtering input in pickers: `"substring"` or `"character"`.

```/dev/null/options-examples.lua#L13-13
options = { picker_filter_type = "character" }
```

🔹 `selected_venv_marker_icon` (default: `"✔"`, type: string)  
Icon used in pickers to mark the currently selected venv (emoji or plain text).

```/dev/null/options-examples.lua#L14-14
options = { selected_venv_marker_icon = "🐍" }
```

🔹 `selected_venv_marker_color` (default: `"#00FF00"`, type: string)  
Hex color used for the selected marker in pickers that support color rendering.

```/dev/null/options-examples.lua#L15-15
options = { selected_venv_marker_color = "#10B981" }
```

🔹 `picker_columns` (default: `{ "marker", "search_icon", "search_name", "search_result" }`, type: array)  
Define which columns appear and their order in pickers; remove entries to hide columns.

```/dev/null/options-examples.lua#L16-16
options = { picker_columns = { "marker", "search_name", "search_result" } }
```

🔹 `picker_options` (default: `{}`, type: table)  
Pass backend-specific options (e.g., `snacks` layout presets).

```/dev/null/options-examples.lua#L17-17
options = { picker_options = { snacks = { layout = { preset = "select" } } } }
```

</details>

---

<details>
<summary>🔔 Notifications & hooks</summary>

🔹 `notify_user_on_venv_activation` (default: `false`, type: boolean)  
Show a notification when a venv is activated.

```/dev/null/options-examples.lua#L18-18
options = { notify_user_on_venv_activation = true }
```

🔹 `override_notify` (default: `true`, type: boolean)  
If `true` and `nvim-notify` is installed, use it instead of `vim.notify` for nicer notifications.

```/dev/null/options-examples.lua#L19-19
options = { override_notify = true }
```

🔹 `on_venv_activate_callback` (default: `nil`, type: function or nil)  
Callback invoked after activation. Receives `(venv_path, env_type)`.

```/dev/null/options-examples.lua#L20-20
options = {
  on_venv_activate_callback = function(venv_path, env_type) print("Activated:", venv_path, env_type) end
}
```

</details>

---

<details>
<summary>🐞 Debugging & advanced</summary>

🔹 `debug` (default: `false`, type: boolean)  
Enable verbose plugin logging. Use `:VenvSelectLog` to inspect logs.

```/dev/null/options-examples.lua#L21-21
options = { debug = true }
```

🔹 `on_telescope_result_callback` (default: `nil`, type: function or nil)  
Transform picker results for display (e.g., shorten paths). Receives raw filename and returns display string.

```/dev/null/options-examples.lua#L22-22
options = { on_telescope_result_callback = function(path) return vim.fn.fnamemodify(path, ":~") end }
```

🔹 `require_lsp_activation` (default: `true`, type: boolean)  
Wait for LSP workspace detection before setting environment variables to avoid premature activation.

```/dev/null/options-examples.lua#L23-23
options = { require_lsp_activation = true }
```

🔹 `statusline_func` (default: `{ nvchad = nil, lualine = nil }`, type: table)  
Provide functions that return status text for supported statusline integrations.

```/dev/null/options-examples.lua#L24-24
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