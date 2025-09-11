local hooks = require("venv-selector.hooks")

local M = {}
M.user_settings = {}
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
                    command =
                    "$FD '/bin/python$' ~/.pyenv/versions --no-ignore-vcs --full-path --color never -E pkgs/ -E envs/ -L",
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
        end,
        ["Darwin"] = function()
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
        end,
        ["Windows_NT"] = function()
            -- NOTE: For windows searches, we convert the string below to a lua table before running it, so the execution doesnt use a shell that needs
            -- a lot of escaping of the strings to get right.
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
        end,
    }

    local name = vim.loop.os_uname().sysname
    return systems[name] or systems["Linux"]
end

function M.merge_user_settings(conf)
    if conf.settings ~= nil then
        conf = conf.settings
        M.has_legacy_settings = true
    end
    local log = require("venv-selector.logger")
    log.debug("User plugin settings: ", conf, "")

    M.user_settings = vim.tbl_deep_extend("force", M.default_settings, conf or {})

    -- Handle backwards compatibility for deprecated options
    if conf and conf.options then
        if conf.options.telescope_active_venv_color and not conf.options.selected_venv_marker_color then
            M.user_settings.options.selected_venv_marker_color = conf.options.telescope_active_venv_color
            log.debug("Using deprecated telescope_active_venv_color for selected_venv_marker_color")
        end
        if conf.options.icon and not conf.options.selected_venv_marker_icon then
            M.user_settings.options.selected_venv_marker_icon = conf.options.icon
            log.debug("Using deprecated icon for selected_venv_marker_icon")
        end
        if conf.options.telescope_filter_type and not conf.options.picker_filter_type then
            M.user_settings.options.picker_filter_type = conf.options.telescope_filter_type
            log.debug("Using deprecated telescope_filter_type for picker_filter_type")
        end
    end

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

M.default_settings = {
    cache = {
        file = "~/.cache/venv-selector/venvs2.json",
    },
    hooks = {
        -- Default hooks for common Python LSPs
        hooks.basedpyright_hook,
        hooks.pyright_hook,
        hooks.jedi_language_server_hook,
        hooks.pylsp_hook,
        hooks.ruff_hook,
        -- hooks.pyrefly_hook,
        -- Dynamic fallback for any other Python LSPs
        hooks.dynamic_python_lsp_hook,
    },
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
        -- show_telescope_search_type is deprecated - use picker_columns instead
        picker_filter_type = "substring", -- When you type something in pickers, filter by "substring" or "character"
        selected_venv_marker_color = "#00FF00", -- The color of the selected venv marker
        selected_venv_marker_icon = "✔", -- The icon to use for marking the selected venv
        picker_icons = {}, -- Override default icons for venv types (e.g., { poetry = "📝", hatch = "🔨", default = "🐍" })
        picker_columns = { "marker", "search_icon", "search_name", "search_result" }, -- Column order in pickers (omit columns to hide them)
        picker = "auto", -- The picker to use. Valid options are "telescope", "fzf-lua", "snacks", "native", "mini-pick" or "auto"
        statusline_func = { nvchad = nil, lualine = nil }
    },
    search = M.get_default_searches()(),
}

return M
