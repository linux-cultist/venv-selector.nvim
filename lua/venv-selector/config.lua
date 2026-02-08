-- lua/venv-selector/config.lua

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
---@field file string Path to cache file

---@class venv-selector.PickerOptions
---@field snacks? table Snacks picker specific options

---@class venv-selector.Options
---@field on_venv_activate_callback? fun()
---@field enable_default_searches boolean
---@field enable_cached_venvs boolean
---@field cached_venv_automatic_activation boolean
---@field activate_venv_in_terminal boolean
---@field set_environment_variables boolean
---@field notify_user_on_venv_activation boolean
---@field override_notify boolean
---@field search_timeout number
---@field debug boolean
---@field fd_binary_name? string
---@field require_lsp_activation boolean
---@field shell? table
---@field on_telescope_result_callback? fun(filename: string): string
---@field picker_filter_type "substring"|"character"
---@field selected_venv_marker_color string
---@field selected_venv_marker_icon string
---@field picker_icons table<string, string>
---@field picker_columns string[]
---@field picker "telescope"|"fzf-lua"|"native"|"mini-pick"|"snacks"|"auto"
---@field statusline_func table
---@field picker_options venv-selector.PickerOptions
---@field telescope_active_venv_color? string
---@field icon? string
---@field telescope_filter_type? string

---@class venv-selector.Settings
---@field cache venv-selector.CacheSettings
---@field hooks venv-selector.Hook[]
---@field options venv-selector.Options
---@field search venv-selector.SearchCommands
---@field detected? table

local M = {}

local uv = vim.uv or vim.loop

---@return string|nil
local function find_fd_command_name()
    for _, cmd in ipairs({ "fd", "fdfind", "fd_find" }) do
        if vim.fn.executable(cmd) == 1 then
            return cmd
        end
    end
    return nil
end

---@return venv-selector.SearchCommands
function M.get_default_searches()
    local system = (uv.os_uname() or {}).sysname

    if system == "Windows_NT" then
        return {
            hatch = {
                command =
                "$FD python.exe $HOME\\AppData\\Local\\hatch\\env\\virtual --no-ignore-vcs --full-path --color never",
            },
            poetry = {
                command =
                "$FD python.exe$ $HOME\\AppData\\Local\\pypoetry\\Cache\\virtualenvs --no-ignore-vcs --full-path --color never",
            },
            pyenv = {
                command =
                "$FD python.exe$ $HOME\\.pyenv\\pyenv-win\\versions $HOME\\.pyenv-win-venv\\envs --no-ignore-vcs -E Lib",
            },
            pipenv = {
                command = "$FD python.exe$ $HOME\\.virtualenvs --no-ignore-vcs --full-path --color never",
            },
            pixi = {
                command =
                "$FD python.exe$ $HOME\\.pixi $CWD\\.pixi -HI --no-ignore-vcs --full-path -a --color never",
            },
            anaconda_envs = {
                command = "$FD python.exe$ $HOME\\anaconda3\\envs --no-ignore-vcs --full-path -a -E Lib",
                type = "anaconda",
            },
            anaconda_base = {
                command = "$FD anaconda3\\\\python.exe$ $HOME\\anaconda3 --no-ignore-vcs --full-path -a --color never",
                type = "anaconda",
            },
            miniconda_envs = {
                command = "$FD python.exe$ $HOME\\miniconda3\\envs --no-ignore-vcs --full-path -a -E Lib",
                type = "anaconda",
            },
            miniconda_base = {
                command = "$FD miniconda3\\\\python.exe$ $HOME\\miniconda3 --no-ignore-vcs --full-path -a --color never",
                type = "anaconda",
            },
            pipx = {
                command = "$FD Scripts\\\\python.exe$ $HOME\\pipx\\venvs --no-ignore-vcs --full-path -a --color never",
            },
            cwd = {
                command = "$FD Scripts\\\\python.exe$ $CWD --full-path --color never -HI -a -L",
            },
            workspace = {
                command = "$FD Scripts\\\\python.exe$ $WORKSPACE_PATH --full-path --color never -HI -a -L",
            },
            file = {
                command = "$FD Scripts\\\\python.exe$ $FILE_DIR --full-path --color never -HI -a -L",
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
                command = "$FD '/bin/python$' ~/.pixi/envs $PIXI_HOME -HI --no-ignore-vcs --full-path --color never",
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
    else
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
                command = "$FD '/bin/python$' ~/.pixi/envs $PIXI_HOME -HI --no-ignore-vcs --full-path --color never",
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

local function default_shell_settings()
    return {
        shellcmdflag = vim.o.shellcmdflag,
        shell = vim.o.shell,
    }
end

---@type venv-selector.Settings
local default_settings = {
    cache = {
        file = "~/.cache/venv-selector/venvs3.json",
    },
    -- keep as table; default hook will be injected if empty
    hooks = {},
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
        fd_binary_name = nil, -- filled in by finalize_settings
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
        shell = default_shell_settings(),
    },
    -- filled in by finalize_settings
    search = {},
}

local function ensure_default_hooks(s)
    -- normalize to table
    if type(s.hooks) ~= "table" then
        s.hooks = {}
    end

    -- user provided hooks (non-empty): respect
    if #s.hooks > 0 then
        return
    end

    -- default hook (lazy require to avoid config<->hooks cycles at module load)
    local ok, hooks_mod = pcall(require, "venv-selector.hooks")
    if ok and hooks_mod and type(hooks_mod.dynamic_python_lsp_hook) == "function" then
        s.hooks = { hooks_mod.dynamic_python_lsp_hook }
    else
        s.hooks = {}
    end
end

local function finalize_settings(s)
    -- shell defaults
    s.options.shell = vim.tbl_deep_extend("force", default_shell_settings(), s.options.shell or {})

    -- fd auto-detect
    if not s.options.fd_binary_name or s.options.fd_binary_name == "" then
        s.options.fd_binary_name = find_fd_command_name()
    end

    -- default searches
    if not s.search or vim.tbl_isempty(s.search) then
        s.search = M.get_default_searches()
    end

    -- default hooks
    ensure_default_hooks(s)

    return s
end

---@type venv-selector.Settings
M.user_settings = finalize_settings(vim.deepcopy(default_settings))

---@param settings venv-selector.Settings|nil
function M.store(settings)
    local log = require("venv-selector.logger")
    log.debug("User plugin settings: ", settings, "")

    M.user_settings = vim.tbl_deep_extend("force", default_settings, settings or {})
    M.user_settings = finalize_settings(M.user_settings)
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

---@return venv-selector.Settings
function M.get_defaults()
    return finalize_settings(vim.deepcopy(default_settings))
end

return M
