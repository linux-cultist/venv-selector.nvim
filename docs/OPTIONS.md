# Options to venv-selector.nvim

## Full listing

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
```

## Examples
<details>
<summary>⚙️  on_venv_activate_callback</summary>
<br>

Use this if you want your own code to get notified when a venv is activated.

In this case, we want to run `poetry env use <python_path>` when these conditions are met:

1. A virtual environment found by the poetry search was activated by the user (its `source` is `poetry`)
2. A terminal was opened afterwards.

The function `on_venv_activate_callback` sets up a neovim autocommand to run the function `run_shell_command` when the terminal opens.

```lua
{
  options = {
    on_venv_activate_callback = function()
      local command_run = false

      local function run_shell_command()
        local source = require("venv-selector").source()
        local python = require("venv-selector").python()

        if source == "poetry" and command_run == false then
          local command = "poetry env use " .. python
          vim.api.nvim_feedkeys(command .. "\n", "n", false)
          command_run = true
        end

      end

      vim.api.nvim_create_augroup("TerminalCommands", { clear = true })

      vim.api.nvim_create_autocmd("TermEnter", {
        group = "TerminalCommands",
        pattern = "*",
        callback = run_shell_command,
      })
    end
  },
}
```
</details>


<details>
<summary>⚙️ on_telescope_result_callback</summary>
<br>

This is for telescope picker only.

The example below shows how to shorten the results shown in telescope. The picker still knows the full path, but it can display a shorter version for convenience.

```lua
-- This function gets called by the plugin when a new result from fd is received
-- You can change the filename displayed here to what you like.
-- Here in the example for linux/mac we replace the home directory with '~' and remove the /bin/python part.
local function shorter_name(filename)
   return filename:gsub(os.getenv("HOME"), "~"):gsub("/bin/python", "")
end

return {
  "linux-cultist/venv-selector.nvim",
  dependencies = {
    { "nvim-telescope/telescope.nvim", version = "*", dependencies = { "nvim-lua/plenary.nvim" } }, -- optional: you can also use fzf-lua, snacks, mini-pick instead.
  },
  ft = "python", -- Load when opening Python files
  keys = {
    { ",v", "<cmd>VenvSelect<cr>" }, -- Open picker on keymap
  },
  opts = {
    options = {
      -- If you put the callback here as a global option, its used for all searches (including the default ones by the plugin)
      on_telescope_result_callback = shorter_name
    },
    search = {
      my_venvs = {
        command = "fd python$ ~/Code", -- Sample command, need to be changed for your own venvs
        -- If you put the callback here, its only called for your "my_venvs" search
        on_telescope_result_callback = shorter_name
      },
    },
  },
},
```
</details>


<details>
<summary>⚙️  shell</summary>
<br>

This is useful for running searches using a different shell and different parameters.

```lua
shell = {
  shell = "bash", -- name of your shell
  shellcmdflag = "-i -c" -- parameters to your shell
}
```

Perhaps you want to use powershell on windows:

```lua
shell = {
  shell = "powershell", -- name of your shell
  shellcmdflag = "-NoLogo -Command" -- parameters to your shell
}
```
</details>


<details>
<summary>⚙️ statusline_func</summary>
<br>

Lualine or nvchad will call this function if you have [configured your neovim to do so](USAGE.md#support-for-lualine-and-nvchad-statusbars).

```lua
options = {
  statusline_func = {
    lualine = function() -- called by lualine
      local venv_path = require("venv-selector").venv()
      if not venv_path or venv_path == "" then
        return ""
      end
    
      local venv_name = vim.fn.fnamemodify(venv_path, ":t")
      if not venv_name then
        return ""
      end
    
      local output = "🐍 " .. venv_name .. " " -- Changes only the icon but you can change colors or use powerline symbols here.
      return output
    end,
    nvchad = function() -- called by nvchad
      local venv_path = require("venv-selector").venv()
      if not venv_path or venv_path == "" then
        return ""
      end
        
      local venv_name = vim.fn.fnamemodify(venv_path, ":t")
      if not venv_name then
        return ""
      end
        
      local output = "🐍 " .. venv_name .. " " -- Changes only the icon but you can change colors or use powerline symbols here.
        return output
      end,
  }
}
```
</details>
