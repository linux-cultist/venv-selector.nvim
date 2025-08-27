local hooks = require("venv-selector.hooks")
-- local log = require("venv-selector.logger")

---@class venv-selector.Options
---@field on_venv_activate_callback? fun(): nil callback function for after a venv activates
---@field enable_default_searches boolean switches all default searches on/off
---@field enable_cached_venvs boolean use cached venvs that are activated automatically when a python file is registered with the LSP.
---@field cached_venv_automatic_activation boolean if set to false, the VenvSelectCached command becomes available to manually activate them.
---@field activate_venv_in_terminal boolean activate the selected python interpreter in terminal windows opened from neovim
---@field set_environment_variables boolean sets VIRTUAL_ENV or CONDA_PREFIX environment variables
---@field notify_user_on_venv_activation boolean notifies user on activation of the virtual env
---@field search_timeout integer if a search takes longer than this many seconds, stop it and alert the user
---@field debug boolean enables you to run the VenvSelectLog command to view debug logs
---@field fd_binary_name string plugin looks for `fd` or `fdfind` but you can set something else here
---@field require_lsp_activation boolean require activation of an lsp before setting env variables
---@field on_telescope_result_callback? fun(filename: string): string callback function for modifying telescope results
---@field show_telescope_search_type boolean Shows which of the searches found which venv in telescope
---@field telescope_filter_type "substring" | "character" When you type something in telescope, filter by "substring" or "character"
---@field telescope_active_venv_color string The color of the active venv in telescope
---@field icon string The icon used for each item in the picker

---@class venv-selector.Settings
---@field cache venv-selector.CacheSettings
---@field hooks venv-selector.Hook[]
---@field options venv-selector.Options
---@field search venv-selector.Searches set or override search commands

---@class (partial) venv-selector.Config: venv-selector.Settings

---@class venv-selector.Detected
---@field system string the detected system name

---@class (partial) venv-selector.UserSettings: venv-selector.Settings
---@field detected venv-selector.Detected

local M = {}

---@type venv-selector.UserSettings
---@diagnostic disable-next-line: missing-fields
M.user_settings = {}


--- Health check tracking of legacy settings
---@type boolean
M.has_legacy_settings = false

function M.get_default_searches()
    local systems = {
        ["Linux"] = function()
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
                    command = "$FD '/bin/python$' ~/.pyenv/versions --no-ignore-vcs --full-path --color never -E pkgs/ -E envs/ -L",
                },
                pipenv = {
                    command = "$FD '/bin/python$' ~/.local/share/virtualenvs --no-ignore-vcs --full-path --color never",
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
                    command = "$FD '/bin/python$' ~/.local/share/pipx/venvs ~/.local/pipx/venvs --no-ignore-vcs --full-path --color never",
                },
                cwd = {
                    command = "$FD '/bin/python$' $CWD --full-path --color never -HI -a -L -E /proc -E .git/ -E .wine/ -E .steam/ -E Steam/ -E site-packages/",
                },
                workspace = {
                    command = "$FD '/bin/python$' $WORKSPACE_PATH --full-path --color never -E /proc -HI -a -L",
                },
                file = {
                    command = "$FD '/bin/python$' $FILE_DIR --full-path --color never -E /proc -HI -a -L",
                },
            }
        end,
        ["Darwin"] = function()
            return {
                virtualenvs = {
                    command = "$FD 'python$' ~/.virtualenvs --no-ignore-vcs --color never",
                },
                hatch = {
                    command = "$FD 'python$' ~/Library/Application\\\\ Support/hatch/env/virtual --no-ignore-vcs --color never -E '*-build*'",
                },
                poetry = {
                    command = "$FD '/bin/python$' ~/Library/Caches/pypoetry/virtualenvs --no-ignore-vcs --full-path",
                },
                pyenv = {
                    command = "$FD '/bin/python$' ~/.pyenv/versions --no-ignore-vcs --full-path --color never -E pkgs/ -E envs/ -L",
                },
                pipenv = {
                    command = "$FD '/bin/python$' ~/.local/share/virtualenvs --no-ignore-vcs --full-path --color never",
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
                    command = "$FD '/bin/python$' ~/.local/share/pipx/venvs ~/.local/pipx/venvs --no-ignore-vcs --full-path --color never",
                },
                cwd = {
                    command = "$FD '/bin/python$' $CWD --full-path --color never -HI -a -L -E /proc -E .git/ -E .wine/ -E .steam/ -E Steam/ -E site-packages/",
                },
                workspace = {
                    command = "$FD '/bin/python$' $WORKSPACE_PATH --full-path --color never -E /proc -HI -a -L",
                },
                file = {
                    command = "$FD '/bin/python$' $FILE_DIR --full-path --color never -E /proc -HI -a -L",
                },
            }
        end,
        ["Windows_NT"] = function()
            -- NOTE: For windows searches, we convert the string below to a lua table before running it, so the execution doesnt use a shell that needs
            -- a lot of escaping of the strings to get right.
            return {
                hatch = {
                    command = "$FD python.exe $HOME/AppData/Local/hatch/env/virtual --no-ignore-vcs --full-path --color never",
                },
                poetry = {
                    command = "$FD python.exe$ $HOME/AppData/Local/pypoetry/Cache/virtualenvs --no-ignore-vcs --full-path --color never",
                },
                pyenv = {
                    command = "$FD python.exe$ $HOME/.pyenv/pyenv-win/versions $HOME/.pyenv-win-venv/envs --no-ignore-vcs -E Lib",
                },
                pipenv = {
                    command = "$FD python.exe$ $HOME/.virtualenvs --no-ignore-vcs --full-path --color never",
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
                    command = "$FD Scripts//python.exe$ $CWD --full-path --color never -HI -a -L",
                },
                workspace = {
                    command = "$FD Scripts//python.exe$ $WORKSPACE_PATH --full-path --color never -HI -a -L",
                },
                file = {
                    command = "$FD Scripts//python.exe$ $FILE_DIR --full-path --color never -HI -a -L",
                },
            }
        end,
    }

    local name = vim.loop.os_uname().sysname
    return systems[name] or systems["Linux"]
end

---@param user_settings venv-selector.Settings
function M.merge_user_settings(conf)
    if conf.settings ~= nil then
        conf = conf.settings
        M.has_legacy_settings = true
    end
    local log = require("venv-selector.logger")
    log.debug("User plugin settings: ", conf, "")

    M.user_settings = vim.tbl_deep_extend("force", M.default_settings, conf or {})

    M.user_settings.detected = {
        system = vim.loop.os_uname().sysname,
    }

    log.debug("Complete user settings:", M.user_settings, "")
end

function M.find_fd_command_name()
    local look_for = { "fd", "fdfind", "fd_find" }
    for _, cmd in ipairs(look_for) do
        if vim.fn.executable(cmd) == 1 then
            return cmd
        end
    end
end

---@type venv-selector.Settings
M.default_settings = {
    cache = {
        file = "~/.cache/venv-selector/venvs2.json",
    },
    hooks = { hooks.basedpyright_hook, hooks.pyright_hook, hooks.pylance_hook, hooks.pylsp_hook },
    options = {
        on_venv_activate_callback = nil, -- callback function for after a venv activates
        enable_default_searches = true, -- switches all default searches on/off
        enable_cached_venvs = true, -- use cached venvs that are activated automatically when a python file is registered with the LSP.
        cached_venv_automatic_activation = true, -- if set to false, the VenvSelectCached command becomes available to manually activate them.
        activate_venv_in_terminal = true, -- activate the selected python interpreter in terminal windows opened from neovim
        set_environment_variables = true, -- sets VIRTUAL_ENV or CONDA_PREFIX environment variables
        notify_user_on_venv_activation = false, -- notifies user on activation of the virtual env
        search_timeout = 5, -- if a search takes longer than this many seconds, stop it and alert the user
        debug = false, -- enables you to run the VenvSelectLog command to view debug logs
        fd_binary_name = M.find_fd_command_name(), -- plugin looks for `fd` or `fdfind` but you can set something else here
        require_lsp_activation = true, -- require activation of an lsp before setting env variables
        -- telescope viewer options
        on_telescope_result_callback = nil, -- callback function for modifying telescope results
        show_telescope_search_type = true, -- Shows which of the searches found which venv in telescope
        telescope_filter_type = "substring", -- When you type something in telescope, filter by "substring" or "character"
        telescope_active_venv_color = "#00FF00", -- The color of the active venv in telescope
        picker = "auto", -- The picker to use. Valid options are "telescope", "fzf-lua", "snacks", "native", "mini-pick" or "auto"
        icon = "", -- The icon to use in the picker for each item
    },
    search = M.get_default_searches()(),
}

return M
