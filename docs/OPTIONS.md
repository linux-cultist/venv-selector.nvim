# ⚙️ venv-selector.nvim — Options reference

This file groups plugin options into topical collapsible sections with short descriptions and ready-to-copy Lua examples. Expand the section for the options you need.

Use these options inside your plugin configuration, e.g.:

```lua
-- in your plugin manager or init.lua
options = {
  -- set plugin options here
}
```

---

<details>
<summary>🔎 Search & discovery options</summary>

- 🔍 `enable_default_searches`  
  Default: `true` — Type: boolean  
  Enable/disable the built-in packaged searches. Set to `false` if you want to provide your own `search` table.

  ```lua
  options = { enable_default_searches = false }
  ```

- ⏱️ `search_timeout`  
  Default: `5` — Type: number (seconds)  
  Stop individual search commands after this many seconds.

  ```lua
  options = { search_timeout = 8 }
  ```

- 🧭 `fd_binary_name`  
  Default: auto-detected (e.g. `fd` / `fdfind`) — Type: string  
  Force which `fd` binary is called. Useful on distros where the binary name differs.

  ```lua
  options = { fd_binary_name = "fdfind" }
  ```

- 🏷️ `picker_icons`  
  Default: `{}` — Type: table  
  Map icons per search/venv type shown in pickers: `{ poetry = "📝", hatch = "🔨", default = "🐍" }`.

  ```lua
  options = { picker_icons = { poetry = "📝", hatch = "🔨", default = "🐍" } }
  ```

</details>

---

<details>
<summary>🗃️ Cache & workspace activation</summary>

- 🗄️ `enable_cached_venvs`  
  Default: `true` — Type: boolean  
  Save & re-apply the last-selected venv per workspace.

  ```lua
  options = { enable_cached_venvs = true }
  ```

- ⚙️ `cached_venv_automatic_activation`  
  Default: `true` — Type: boolean  
  If `false`, cached venvs won't activate automatically; use `:VenvSelectCached` to apply them manually.

  ```lua
  options = { cached_venv_automatic_activation = false }
  ```

- 📁 `cache.file` (advanced)  
  Default: `~/.cache/venv-selector/venvs2.json` — Type: string  
  Path to on-disk cache; advanced override.

  ```lua
  -- advanced / not common
  options = {}
  settings = { cache = { file = vim.fn.expand("~/.cache/my-venv-cache.json") } }
  ```

</details>

---

<details>
<summary>🖥️ Terminal, environment & shell</summary>

- 🧪 `activate_venv_in_terminal`  
  Default: `true` — Type: boolean  
  Try to activate the selected venv in new terminals opened from Neovim so they inherit the environment.

  ```lua
  options = { activate_venv_in_terminal = true }
  ```

- 🌐 `set_environment_variables`  
  Default: `true` — Type: boolean  
  Whether the plugin sets `VIRTUAL_ENV` or `CONDA_PREFIX` on activation.

  ```lua
  options = { set_environment_variables = true }
  ```

- 🐚 `shell`  
  Default: `{ shell = vim.o.shell, shellcmdflag = vim.o.shellcmdflag }` — Type: table  
  Override the shell and shell flags used when running search commands (useful for Fish, etc.).

  ```lua
  options = { shell = { shell = "/usr/bin/fish", shellcmdflag = "-c" } }
  ```

</details>

---

<details>
<summary>🧭 Picker & UI options</summary>

- 🧰 `picker`  
  Default: `"auto"` — Type: string  
  Which picker backend to use: `"telescope"`, `"fzf-lua"`, `"snacks"`, `"native"`, `"mini-pick"`, or `"auto"`.

  ```lua
  options = { picker = "telescope" }
  ```

- 🔎 `picker_filter_type`  
  Default: `"substring"` — Type: string (`"substring"` or `"character"`)  
  How typed input filters picker results.

  ```lua
  options = { picker_filter_type = "character" }
  ```

- ✅ `selected_venv_marker_icon`  
  Default: `"✔"` — Type: string  
  Icon used to mark the selected venv in pickers (emoji or text).

  ```lua
  options = { selected_venv_marker_icon = "🐍" }
  ```

- 🎨 `selected_venv_marker_color`  
  Default: `"#00FF00"` — Type: string  
  Hex color used for the selected marker (pickers supporting color).

  ```lua
  options = { selected_venv_marker_color = "#10B981" }
  ```

- 📐 `picker_columns`  
  Default: `{ "marker", "search_icon", "search_name", "search_result" }` — Type: array  
  Column order in pickers; remove entries to hide columns.

  ```lua
  options = { picker_columns = { "marker", "search_name", "search_result" } }
  ```

- ⚙️ `picker_options`  
  Default: `{}` — Type: table  
  Backend-specific picker options (e.g., snacks layout presets).

  ```lua
  options = { picker_options = { snacks = { layout = { preset = "select" } } } }
  ```

</details>

---

<details>
<summary>🔔 Notifications & hooks</summary>

- 🔔 `notify_user_on_venv_activation`  
  Default: `false` — Type: boolean  
  Show a user notification when a venv is activated.

  ```lua
  options = { notify_user_on_venv_activation = true }
  ```

- 🔁 `override_notify`  
  Default: `true` — Type: boolean  
  Use `nvim-notify` (if installed) instead of `vim.notify` for nicer notifications.

  ```lua
  options = { override_notify = true }
  ```

- 🪝 `on_venv_activate_callback`  
  Default: `nil` — Type: function or nil  
  Callback invoked after activation. Receives `(venv_path, env_type)`.

  ```lua
  options = {
    on_venv_activate_callback = function(venv_path, env_type)
      print("Activated venv:", venv_path, "type:", env_type)
    end
  }
  ```

</details>

---

<details>
<summary>🐞 Debugging & advanced</summary>

- 🐛 `debug`  
  Default: `false` — Type: boolean  
  Enable verbose plugin logging. Use `:VenvSelectLog` to inspect logs.

  ```lua
  options = { debug = true }
  ```

- 🧩 `on_telescope_result_callback`  
  Default: `nil` — Type: function or nil  
  Transform picker results (e.g., shorten displayed path). Receives the raw filename and returns a display string.

  ```lua
  options = {
    on_telescope_result_callback = function(path)
      return vim.fn.fnamemodify(path, ":~")
    end
  }
  ```

- 🧭 `require_lsp_activation`  
  Default: `true` — Type: boolean  
  Wait for LSP workspace detection before setting environment variables (helps avoid premature activation).

  ```lua
  options = { require_lsp_activation = true }
  ```

- 📊 `statusline_func`  
  Default: `{ nvchad = nil, lualine = nil }` — Type: table  
  Provide functions to return statusline text for supported statusline plugins.

  ```lua
  options = {
    statusline_func = {
      lualine = function() return require("venv-selector").get_status() end,
      nvchad = function() return require("venv-selector").get_status() end
    }
  }
  ```

</details>

---

## Quick examples

- Minimal commonly-used tweaks:

```lua
options = { debug = true, picker = "auto", selected_venv_marker_icon = "🐍" }
```

- Disable built-ins and add a custom `fd` search:

```lua
options = { enable_default_searches = false }
search = {
  my_project_venvs = { command = "fd '/bin/python$' ~/Code --full-path --color never" }
}
```

---

If you want I can:
- Re-group to fewer high-level categories (Search / Picker / Notifications / Cache) and collapse each by default.
- Add a short "cheat-sheet" showing the 6 most commonly customized options at the top.
- Provide ready-to-drop config examples for common setups (Telescope + lualine, fzf-lua + nvchad, etc.).