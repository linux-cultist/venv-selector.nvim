# venv-selector.nvim — consolidated options example
#
# Paste the `options = { ... }` block below into your plugin config (inside
# your plugin manager spec or wherever you call `require("venv-selector").setup`).
# Each option line has an inline comment describing the default and what it does.
#
# Note: replace placeholder/example values with the settings you actually want.

```lua
options = {
  -- on_venv_activate_callback = nil,            -- default: nil (function|nil)
  -- Callback called after a venv is activated. Signature: function(venv_path, env_type)
  on_venv_activate_callback = nil,

  -- enable_default_searches = true,            -- default: true (boolean)
  -- When true, use built-in fd-based searches. Set false to provide your own `search` table.
  enable_default_searches = true,

  -- enable_cached_venvs = true,                -- default: true (boolean)
  -- Cache last-selected venv per workspace and optionally reapply.
  enable_cached_venvs = true,

  -- cached_venv_automatic_activation = true,   -- default: true (boolean)
  -- When true, cached venvs are applied automatically for known workspaces. Set false to require manual activation.
  cached_venv_automatic_activation = true,

  -- activate_venv_in_terminal = true,          -- default: true (boolean)
  -- If true, new terminals spawned from Neovim will attempt to use the selected venv.
  activate_venv_in_terminal = true,

  -- set_environment_variables = true,          -- default: true (boolean)
  -- If true, sets VIRTUAL_ENV or CONDA_PREFIX in Neovim's environment on activation.
  set_environment_variables = true,

  -- notify_user_on_venv_activation = false,    -- default: false (boolean)
  -- Show a user notification when a venv is activated.
  notify_user_on_venv_activation = false,

  -- override_notify = true,                    -- default: true (boolean)
  -- If true and nvim-notify is available, use it instead of vim.notify.
  override_notify = true,

  -- search_timeout = 5,                        -- default: 5 (number - seconds)
  -- Timeout in seconds for individual search commands (fd). Longer values for slow disks.
  search_timeout = 5,

  -- debug = false,                             -- default: false (boolean)
  -- Enables debug logging. Use `:VenvSelectLog` to inspect traces.
  debug = false,

  -- fd_binary_name = nil,                      -- default: auto-detected (string|nil)
  -- Force the fd binary name (e.g., "fd" or "fdfind"). Nil = auto-detect.
  fd_binary_name = nil,

  -- require_lsp_activation = true,             -- default: true (boolean)
  -- If true, wait for LSP workspace detection before applying environment (helps avoid premature activation).
  require_lsp_activation = true,

  -- shell = { shell = vim.o.shell, shellcmdflag = vim.o.shellcmdflag } -- default (table)
  -- Override the shell and shellcmdflag used to run search commands (useful for fish/zsh configs).
  shell = { shell = vim.o.shell, shellcmdflag = vim.o.shellcmdflag },

  -- on_telescope_result_callback = nil,        -- default: nil (function|nil)
  -- Optional transform function for picker results: function(path) -> display_string
  on_telescope_result_callback = nil,

  -- picker_filter_type = "substring",          -- default: "substring" (string: "substring"|"character")
  -- Controls how pickers filter results while typing.
  picker_filter_type = "substring",

  -- selected_venv_marker_color = "#00FF00",    -- default: "#00FF00" (string - hex color)
  -- Color used for marking the selected venv in color-capable pickers.
  selected_venv_marker_color = "#00FF00",

  -- selected_venv_marker_icon = "✔",           -- default: "✔" (string)
  -- Icon/text used to mark the currently-selected venv in the picker UI.
  selected_venv_marker_icon = "✔",

  -- picker_icons = {},                         -- default: {} (table)
  -- Map of icons for venv/search types, e.g. { poetry = "📝", hatch = "🔨", default = "🐍" }.
  picker_icons = {},

  -- picker_columns = { "marker", "search_icon", "search_name", "search_result" } -- default (array)
  -- Control which columns appear in pickers and their order. Omit to hide.
  picker_columns = { "marker", "search_icon", "search_name", "search_result" },

  -- picker_options = {},                       -- default: {} (table)
  -- Backend-specific options passed to the active picker (e.g., snacks layout presets).
  picker_options = {},

  -- picker = "auto",                           -- default: "auto" (string)
  -- Picker backend to prefer: "telescope", "fzf-lua", "snacks", "native", "mini-pick", or "auto".
  picker = "auto",

  -- statusline_func = { nvchad = nil, lualine = nil } -- default (table)
  -- Provide functions for statusline integrations that return a string.
  statusline_func = { nvchad = nil, lualine = nil },
}

-- Example `search` table placeholder: supply your own searches if you disabled defaults.
-- search = {
--   my_project_venvs = { command = "fd '/bin/python$' ~/Code --full-path --color never" },
--   my_conda = { command = "$FD 'python.exe$' $HOME/anaconda3 --full-path --color never", type = "anaconda" },
-- }