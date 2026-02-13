# ⚙️ venv-selector.nvim — Options reference

This file groups plugin options into topical sections with short descriptions and ready-to-copy Lua examples. Each section is collapsible — expand the area for the options and examples you need.

Use these options in your plugin configuration, for example:
```/dev/null/usage-quickstart.lua#L1-4
require("venv-selector").setup {
  options = {
    -- set plugin options here
  },
  search = {
    -- custom search definitions (optional)
  }
}
```

---

<details>
<summary>🔎 Search & discovery options</summary>

#### `enable_default_searches`
- Default: `true` — Type: boolean  
Enable/disable the built-in, packaged searches. Disable to provide your own `search` table.

```/dev/null/options-examples.lua#L1-5
require("venv-selector").setup {
  options = { enable_default_searches = false },
  search = {
    my_project_venvs = { command = "fd '/bin/python$' ~/Code --full-path --color never" }
  }
}
```

#### `search_timeout`
- Default: `5` — Type: number (seconds)  
Stop individual search commands after this many seconds.

```/dev/null/options-examples.lua#L6-10
require("venv-selector").setup {
  options = { search_timeout = 8 } -- increase timeout for slow file systems
}
```

#### `fd_binary_name`
- Default: auto-detected (`fd` / `fdfind`) — Type: string  
Force which `fd` binary to call.

```/dev/null/options-examples.lua#L11-14
require("venv-selector").setup {
  options = { fd_binary_name = "fdfind" } -- explicit on distributions where fd is fdfind
}
```

#### `picker_icons`
- Default: `{}` — Type: table  
Map icons per search/venv type (in pickers).

```/dev/null/options-examples.lua#L15-20
require("venv-selector").setup {
  options = {
    picker_icons = { poetry = "📝", hatch = "🔨", default = "🐍" }
  }
}
```

</details>

---

<details>
<summary>🗃️ Cache & workspace activation</summary>

#### `enable_cached_venvs`
- Default: `true` — Type: boolean  
Enable storing the last-selected venv per workspace so it can be re-applied automatically.

```/dev/null/options-examples.lua#L21-25
require("venv-selector").setup {
  options = { enable_cached_venvs = true }
}
```

#### `cached_venv_automatic_activation`
- Default: `true` — Type: boolean  
If `false`, cached venvs won't be activated automatically; use `:VenvSelectCached`.

```/dev/null/options-examples.lua#L26-29
require("venv-selector").setup {
  options = { cached_venv_automatic_activation = false }
}
```

#### `cache.file` (in `Settings` / advanced)
- Default: `~/.cache/venv-selector/venvs2.json` — Type: string  
Path to the on-disk cache (advanced override).

```/dev/null/options-examples.lua#L30-35
-- Advanced: change cache path
require("venv-selector").setup {
  settings = { cache = { file = vim.fn.expand("~/.cache/my-venv-cache.json") } }
}
```

</details>

---

<details>
<summary>🖥️ Terminal, environment & shell</summary>

#### `activate_venv_in_terminal`
- Default: `true` — Type: boolean  
Attempt to apply the selected venv inside new terminals spawned from Neovim.

```/dev/null/options-examples.lua#L36-40
require("venv-selector").setup {
  options = { activate_venv_in_terminal = true }
}
```

#### `set_environment_variables`
- Default: `true` — Type: boolean  
Whether to set `VIRTUAL_ENV` or `CONDA_PREFIX` when activating.

```/dev/null/options-examples.lua#L41-45
require("venv-selector").setup {
  options = { set_environment_variables = true }
}
```

#### `shell`
- Default: `{ shell = vim.o.shell, shellcmdflag = vim.o.shellcmdflag }` — Type: table  
Override the shell and flags used to run search commands (useful for Fish, etc.)

```/dev/null/options-examples.lua#L46-51
require("venv-selector").setup {
  options = { shell = { shell = "/usr/bin/fish", shellcmdflag = "-c" } }
}
```

</details>

---

<details>
<summary>🧭 Picker & UI options</summary>

#### `picker`
- Default: `"auto"` — Type: string  
Which picker backend to use: `"telescope"`, `"fzf-lua"`, `"snacks"`, `"native"`, `"mini-pick"`, or `"auto"`.

```/dev/null/options-examples.lua#L52-56
require("venv-selector").setup {
  options = { picker = "telescope" }
}
```

#### `picker_filter_type`
- Default: `"substring"` — Type: string (`"substring"` or `"character"`)  
Controls how typed input filters results in pickers.

```/dev/null/options-examples.lua#L57-60
require("venv-selector").setup {
  options = { picker_filter_type = "character" }
}
```

#### `selected_venv_marker_icon`
- Default: `"✔"` — Type: string  
Icon displayed for the currently selected venv in pickers.

```/dev/null/options-examples.lua#L61-64
require("venv-selector").setup {
  options = { selected_venv_marker_icon = "🐍" }
}
```

#### `selected_venv_marker_color`
- Default: `"#00FF00"` — Type: string  
Hex color for the selected marker (pickers that support color).

```/dev/null/options-examples.lua#L65-68
require("venv-selector").setup {
  options = { selected_venv_marker_color = "#10B981" }
}
```

#### `picker_columns`
- Default: `{ "marker", "search_icon", "search_name", "search_result" }` — Type: array  
Control which columns appear and their order.

```/dev/null/options-examples.lua#L69-75
require("venv-selector").setup {
  options = { picker_columns = { "marker", "search_name", "search_result" } }
}
```

#### `picker_options`
- Default: `{}` — Type: table  
Picker-specific options passed to the selected backend.

```/dev/null/options-examples.lua#L76-82
require("venv-selector").setup {
  options = {
    picker_options = {
      snacks = { layout = { preset = "select" } }
    }
  }
}
```

</details>

---

<details>
<summary>🔔 Notifications & hooks</summary>

#### `notify_user_on_venv_activation`
- Default: `false` — Type: boolean  
Show a notification when a venv is activated.

```/dev/null/options-examples.lua#L83-88
require("venv-selector").setup {
  options = { notify_user_on_venv_activation = true }
}
```

#### `override_notify`
- Default: `true` — Type: boolean  
If `true` and `nvim-notify` is available, use it instead of `vim.notify`.

```/dev/null/options-examples.lua#L89-93
require("venv-selector").setup {
  options = { override_notify = true }
}
```

#### `on_venv_activate_callback`
- Default: `nil` — Type: function or nil  
Callback invoked after a venv activates. Receives (venv_path, env_type).

```/dev/null/options-examples.lua#L94-100
require("venv-selector").setup {
  options = {
    on_venv_activate_callback = function(venv_path, env_type)
      print("Activated venv:", venv_path, "type:", env_type)
    end
  }
}
```

</details>

---

<details>
<summary>🐞 Debugging & advanced</summary>

#### `debug`
- Default: `false` — Type: boolean  
Enable verbose plugin logging. Use `:VenvSelectLog` to view logs when set.

```/dev/null/options-examples.lua#L101-104
require("venv-selector").setup {
  options = { debug = true }
}
```

#### `on_telescope_result_callback`
- Default: `nil` — Type: function or nil  
Transform picker results (e.g., shorten displayed path).

```/dev/null/options-examples.lua#L105-110
require("venv-selector").setup {
  options = {
    on_telescope_result_callback = function(path)
      return vim.fn.fnamemodify(path, ":~")
    end
  }
}
```

#### `require_lsp_activation`
- Default: `true` — Type: boolean  
If `true`, wait for LSP workspace detection to avoid premature activation.

```/dev/null/options-examples.lua#L111-114
require("venv-selector").setup {
  options = { require_lsp_activation = true }
}
```

#### `statusline_func`
- Default: `{ nvchad = nil, lualine = nil }` — Type: table  
Provide functions to return a statusline string for supported statusline plugins.

```/dev/null/options-examples.lua#L115-122
require("venv-selector").setup {
  options = {
    statusline_func = {
      lualine = function() return require("venv-selector").get_status() end,
      nvchad = function() return require("venv-selector").get_status() end
    }
  }
}
```

</details>

---

## Examples & quick patterns

- Minimal toggleable config:
```/dev/null/examples/minimal.lua#L1-6
require("venv-selector").setup {
  options = { debug = true, picker = "auto", selected_venv_marker_icon = "🐍" }
}
```

- Disable built-ins and provide custom `fd` search:
```/dev/null/examples/custom_search.lua#L1-10
require("venv-selector").setup {
  options = { enable_default_searches = false },
  search = {
    my_project_venvs = {
      command = "fd '/bin/python$' ~/Code --full-path --color never"
    }
  }
}
```

---

If you'd like, I can:
- Group options further (Search / Picker / Notifications / Cache) and collapse each group by default.
- Add an at-a-glance "cheat sheet" with the most commonly customized options.
- Generate ready-to-drop examples for popular setups (Telescope + lualine, fzf-lua + nvchad, etc.).

Pick one and I will update just the docs accordingly.