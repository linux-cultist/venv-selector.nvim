local hooks = require("venv-selector.hooks")

---@class venv-selector.SearchCommand
---@field command string The command to execute for finding python interpreters
---@field type? string Optional type identifier (e.g., "anaconda")

---@class venv-selector.SearchCommands
---@field virtualenvs? venv-selector.SearchCommand
---@field hatch? venv-selector.SearchCommand
---@field poetry? venv-selector.SearchCommand
---@field pyenv? venv-selector.SearchCommand
---@field pipenv? venv-selector.SearchCommand
---@field pixi? venv-selector.SearchCommand
---@field anaconda_envs? venv-selector.SearchCommand
---@field anaconda_base? venv-selector.SearchCommand
---@field miniconda_envs? venv-selector.SearchCommand
---@field miniconda_base? venv-selector.SearchCommand
---@field pipx? venv-selector.SearchCommand
---@field cwd? venv-selector.SearchCommand
---@field workspace? venv-selector.SearchCommand
---@field file? venv-selector.SearchCommand

---@alias venv-selector.Hook fun(venv_python: string|nil, env_type: string|nil)

---@class venv-selector.CacheSettings
---@field file string Path to cache file (default: "~/.cache/venv-selector/venvs2.json")

---@class venv-selector.PickerOptions
---@field snacks? table Snacks picker specific options (default: { layout = { preset = "select" } })

---@class venv-selector.Options
---@field on_venv_activate_callback? fun(venv_python: string|nil, env_type: string|nil) Callback function for after a venv activates (default: nil)
---@field enable_default_searches boolean Switches all default searches on/off (default: true)
---@field enable_cached_venvs boolean Use cached venvs that are activated automatically (default: true)
---@field cached_venv_automatic_activation boolean If false, VenvSelectCached command becomes available for manual activation (default: true)
---@field activate_venv_in_terminal boolean Activate the selected python interpreter in terminal windows (default: true)
---@field set_environment_variables boolean Sets VIRTUAL_ENV or CONDA_PREFIX environment variables (default: true)
---@field notify_user_on_venv_activation boolean Notifies user on activation of the virtual env (default: false)
---@field override_notify boolean  Override built-in vim.notify with nvim-notify plugin if its installed (default: true)
---@field search_timeout number If a search takes longer than this many seconds, stop it (default: 5)
---@field debug boolean Enables VenvSelectLog command to view debug logs (default: false)
---@field fd_binary_name? string Name of fd binary to use (fd, fdfind, etc.) (default: auto-detected)
---@field require_lsp_activation boolean Require activation of an lsp before setting env variables (default: true)
---@field shell? table Allows you to override what shell and shell flags to use for the searches (may be different from your default shell)
---@field on_telescope_result_callback? fun(filename: string): string Callback for modifying telescope results (default: nil)
---@field picker_filter_type "substring"|"character" Filter by substring or character in pickers (default: "substring")
---@field selected_venv_marker_color string The color of the selected venv marker (default: "#00FF00")
---@field selected_venv_marker_icon string The icon to use for marking the selected venv (default: "✔")
---@field picker_icons table<string, string> Override default icons for venv types (default: {})
---@field picker_columns string[] Column order in pickers (default: { "marker", "search_icon", "search_name", "search_result" })
---@field picker "telescope"|"fzf-lua"|"native"|"mini-pick"|"snacks"|"auto" The picker to use (default: "auto")
---@field statusline_func table Statusline functions for different statusline plugins (default: { nvchad = nil, lualine = nil })
---@field picker_options venv-selector.PickerOptions Picker-specific options
---@field telescope_active_venv_color? string Deprecated: use selected_venv_marker_color
---@field icon? string Deprecated: use selected_venv_marker_icon
---@field telescope_filter_type? string Deprecated: use picker_filter_type

---@class venv-selector.Settings
---@field cache venv-selector.CacheSettings Cache configuration (default: { file = "~/.cache/venv-selector/venvs2.json" })
---@field hooks venv-selector.Hook[] Hook functions called on venv activation (default: { hooks.dynamic_python_lsp_hook })
---@field options venv-selector.Options Plugin options (see venv-selector.Options for defaults)
---@field search venv-selector.SearchCommands Search commands for finding virtual environments (default: OS-specific searches)
---@field detected? table Detected system information

local M = {}

---Find the fd command name available on the system
---@return string|nil
local function find_fd_command_name()
    local look_for = { "fd", "fdfind", "fd_find" }
    for _, cmd in ipairs(look_for) do
        if vim.fn.executable(cmd) == 1 then
            return cmd
        end
    end
    return nil
end

---Get default search commands for the current operating system
---@return venv-selector.SearchCommands
function M.get_default_searches()
    local system = vim.loop.os_uname().sysname

    if system == "Windows_NT" then
        return {
            hatch = {
                command =
                "$FD python.exe $HOME/AppData/Local/hatch/env/virtual --no-ignore-vcs --full-path --color never",
            },
            poetry = {
                command =
                "$FD python.exe$ $HOME/AppData/Local/pypoetry/Cache/virtualenvs --no-ignore-vcs --full-path --color never",
            },
            pyenv = {
                command =
                "$FD python.exe$ $HOME/.pyenv/pyenv-win/versions $HOME/.pyenv-win-venv/envs --no-ignore-vcs -E Lib",
            },
            pipenv = {
                command = "$FD python.exe$ $HOME/.virtualenvs --no-ignore-vcs --full-path --color never",
            },
            pixi = {
                command =
                "$FD python.exe$ $CWD/.pixi/envs $WORKSPACE_PATH/.pixi/envs $FILE_DIR/.pixi/envs $HOME/.pixi/envs -d 2 --no-ignore-vcs --full-path --color never",
            },
            anaconda_envs = {
                command = "$FD python.exe$ $HOME/anaconda3/envs --no-ignore-vcs --full-path -a -E Lib",
                type = "anaconda",
            },
            anaconda_base = {
                command = "$FD anaconda3//python.exe $HOME/anaconda3 --no-ignore-vcs --full-path -a --color never",
                type = "anaconda",
            },
            miniconda_envs = {
                command = "$FD python.exe$ $HOME/miniconda3/envs --no-ignore-vcs --full-path -a -E Lib",
                type = "anaconda",
            },
            miniconda_base = {
                command = "$FD miniconda3//python.exe $HOME/miniconda3 --no-ignore-vcs --full-path -a --color never",
                type = "anaconda",
            },
            pipx = {
                command = "$FD Scripts//python.exe$ $HOME/pipx/venvs --no-ignore-vcs --full-path -a --color never",
            },
            cwd = {
                command = "$FD Scripts//python.exe$ '$CWD' --full-path --color never -HI -a -L",
            },
            workspace = {
                command = "$FD Scripts//python.exe$ '$WORKSPACE_PATH' --full-path --color never -HI -a -L",
            },
            file = {
                command = "$FD Scripts//python.exe$ '$FILE_DIR' --full-path --color never -HI -a -L",
            },
        }
    elseif system == "Darwin" then
        return {
            virtualenvs = {
                command = "$FD 'python$' ~/.virtualenvs --no-ignore-vcs --color never",
            },
            hatch = {
                command =
                "$FD 'python$' ~/Library/Application\\\\ Support/hatch/env/virtual --no-ignore-vcs --color never -E '*-build*'",
            },
            poetry = {
                command = "$FD '/bin/python$' ~/Library/Caches/pypoetry/virtualenvs --no-ignore-vcs --full-path",
            },
            pyenv = {
                command =
                "$FD '/bin/python$' ~/.pyenv/versions --no-ignore-vcs --full-path --color never -E pkgs/ -E envs/ -L",
            },
            pipenv = {
                command = "$FD '/bin/python$' ~/.local/share/virtualenvs --no-ignore-vcs --full-path --color never",
            },
            pixi = {
                command = "$FD '/bin/python$' ~/.pixi/envs --no-ignore-vcs --full-path --color never",
            },
            anaconda_envs = {
                command = "$FD 'bin/python$' ~/.conda/envs --no-ignore-vcs --full-path --color never",
                type = "anaconda",
            },
            anaconda_base = {
                command = "$FD '/python$' /opt/anaconda/bin --full-path --color never",
                type = "anaconda",
            },
            miniconda_envs = {
                command = "$FD 'bin/python$' ~/miniconda3/envs --no-ignore-vcs --full-path --color never",
                type = "anaconda",
            },
            miniconda_base = {
                command = "$FD '/python$' ~/miniconda3/bin --no-ignore-vcs --full-path --color never",
                type = "anaconda",
            },
            pipx = {
                command =
                "$FD '/bin/python$' ~/.local/share/pipx/venvs ~/.local/pipx/venvs --no-ignore-vcs --full-path --color never",
            },
            cwd = {
                command =
                "$FD '/bin/python$' '$CWD' --full-path --color never -HI -a -L -E /proc -E .git/ -E .wine/ -E .steam/ -E Steam/ -E site-packages/",
            },
            workspace = {
                command = "$FD '/bin/python$' '$WORKSPACE_PATH' --full-path --color never -E /proc -HI -a -L",
            },
            file = {
                command = "$FD '/bin/python$' '$FILE_DIR' --full-path --color never -E /proc -HI -a -L",
            },
        }
    else -- Linux and other Unix-like systems
        return {
            virtualenvs = {
                command = "$FD 'python$' ~/.virtualenvs --no-ignore-vcs --color never",
            },
            hatch = {
                command = "$FD 'python$' ~/.local/share/hatch --no-ignore-vcs --color never -E '*-build*'",
            },
            poetry = {
                command = "$FD '/bin/python$' ~/.cache/pypoetry/virtualenvs --no-ignore-vcs --full-path",
            },
            pyenv = {
                command =
                "$FD '/bin/python$' ~/.pyenv/versions --no-ignore-vcs --full-path --color never -E pkgs/ -E envs/ -L",
            },
            pipenv = {
                command = "$FD '/bin/python$' ~/.local/share/virtualenvs --no-ignore-vcs --full-path --color never",
            },
            pixi = {
                command = "$FD '/bin/python$' ~/.pixi/envs --no-ignore-vcs --full-path --color never",
            },
            anaconda_envs = {
                command = "$FD 'bin/python$' ~/.conda/envs --no-ignore-vcs --full-path --color never",
                type = "anaconda",
            },
            anaconda_base = {
                command = "$FD '/python$' /opt/anaconda/bin --full-path --color never",
                type = "anaconda",
            },
            miniconda_envs = {
                command = "$FD 'bin/python$' ~/miniconda3/envs --no-ignore-vcs --full-path --color never",
                type = "anaconda",
            },
            miniconda_base = {
                command = "$FD '/python$' ~/miniconda3/bin --no-ignore-vcs --full-path --color never",
                type = "anaconda",
            },
            pipx = {
                command =
                "$FD '/bin/python$' ~/.local/share/pipx/venvs ~/.local/pipx/venvs --no-ignore-vcs --full-path --color never",
            },
            cwd = {
                command =
                "$FD '/bin/python$' '$CWD' --full-path --color never -HI -a -L -E /proc -E .git/ -E .wine/ -E .steam/ -E Steam/ -E site-packages/",
            },
            workspace = {
                command = "$FD '/bin/python$' '$WORKSPACE_PATH' --full-path --color never -E /proc -HI -a -L",
            },
            file = {
                command = "$FD '/bin/python$' '$FILE_DIR' --full-path --color never -E /proc -HI -a -L",
            },
        }
    end
end

---Default settings with full type annotations for autocomplete
---@type venv-selector.Settings
local default_settings = {
    cache = {
        file = "~/.cache/venv-selector/venvs2.json",
    },
    hooks = {
        hooks.dynamic_python_lsp_hook,
    },
    options = {
        on_venv_activate_callback = nil,
        enable_default_searches = true,
        enable_cached_venvs = true,
        cached_venv_automatic_activation = true,
        activate_venv_in_terminal = true,
        set_environment_variables = true,
        notify_user_on_venv_activation = false,
        override_notify = true,
        search_timeout = 5,
        debug = false,
        fd_binary_name = find_fd_command_name(),
        require_lsp_activation = true,
        on_telescope_result_callback = nil,
        picker_filter_type = "substring",
        selected_venv_marker_color = "#00FF00",
        selected_venv_marker_icon = "✔",
        picker_icons = {},
        picker_columns = { "marker", "search_icon", "search_name", "search_result" },
        picker = "auto",
        statusline_func = { nvchad = nil, lualine = nil },
        show_telescope_search_type = false,
        picker_options = {
            snacks = {
                layout = { preset = "select" },
            },
        },
        shell = {
            shellcmdflag = vim.o.shellcmdflag,
            shell = vim.o.shell
        }
    },
    search = M.get_default_searches(),
}

---Initialize user_settings with defaults for immediate autocomplete support
---@type venv-selector.Settings
M.user_settings = vim.deepcopy(default_settings)

---Merge user configuration with default settings
---@param settings venv-selector.Settings|nil User configuration
function M.store(settings)
    local log = require("venv-selector.logger")
    log.debug("User plugin settings: ", settings, "")
    -- Deep merge user settings with defaults
    M.user_settings = vim.tbl_deep_extend("force", default_settings, settings or {})
    return M.get_user_settings()
end

---@return venv-selector.Options
function M.get_user_options()
    return M.user_settings.options
end

---@return venv-selector.Settings
function M.get_user_settings()
    return M.user_settings
end

---Get the default settings (useful for documentation or testing)
---@return venv-selector.Settings
function M.get_defaults()
    return vim.deepcopy(default_settings)
end

return M
