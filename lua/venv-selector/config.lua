local hooks = require 'venv-selector.hooks'

local M = {}

M.user_settings = {}

function M.get_default_searches()
    local systems = {
        ['Linux'] = function()
            return {
                virtualenvs = {
                    command = "$FD python$ ~/.virtualenvs --color never -E /proc"
                },
                hatch = {
                    command = "$FD python$ ~/.local/share/hatch --color never -E /proc"
                },
                poetry = {
                    command = "$FD /bin/python3$ ~/.cache/pypoetry/virtualenvs --full-path"
                },
                pyenv = {
                    command = "$FD 'versions/([0-9.]+)/bin/python$' ~/.pyenv/versions --full-path --color never -E /proc"
                },
                anaconda_envs = {
                    command = "$FD bin/python$ ~/.conda/envs --full-path --color never -E /proc",
                    type = "anaconda"
                },
                anaconda_base = {
                    command = "$FD /python$ /opt/anaconda/bin --full-path --color never -E /proc",
                    type = "anaconda"
                },
                cwd = {
                    command = "$FD /bin/python$ $CWD --full-path --color never -E /proc -HI",
                },
                workspace = {
                    command = "$FD /bin/python$ $WORKSPACE_PATH --full-path --color never -E /proc -HI",
                }
            }
        end,
        ['Darwin'] = function()
            return {
                virtualenvs = {
                    command = "$FD python$ ~/.virtualenvs --color never -E /proc"
                },
                hatch = {
                    command = "$FD python$ ~/.local/share/hatch --color never -E /proc"
                },
                poetry = {
                    command = "$FD /bin/python3$ ~/.cache/pypoetry/virtualenvs --full-path"
                },
                pyenv = {
                    command = "$FD 'versions/([0-9.]+)/bin/python$' ~/.pyenv/versions --full-path --color never -E /proc"
                },
                anaconda_envs = {
                    command = "$FD bin/python$ ~/.conda/envs --full-path --color never -E /proc"
                },
                anaconda_base = {
                    command = "$FD /python$ /opt/anaconda/bin --full-path --color never -E /proc",
                },
                cwd = {
                    command = "$FD /bin/python$ $CWD --full-path --color never -E /proc -HI",
                },
                workspace = {
                    command = "$FD /bin/python$ $WORKSPACE_PATH --full-path --color never -E /proc -HI",
                }
            }
        end,
        ['Windows_NT'] = function()
            return {
                hatch = {
                    command = "$FD python.exe $HOME/AppData/Local/hatch/env/virtual --full-path --color never"
                },
                poetry = {
                    command = "$FD python.exe$ $HOME/AppData/Local/pypoetry/Cache/virtualenvs --full-path --color never"
                },
                pyenv = {
                    command = "$FD python.exe$ $HOME/.pyenv/pyenv-win/versions -E Lib"
                },
                anaconda_envs = {
                    command = "$FD python.exe$ $HOME/anaconda3/envs --full-path -a -E Lib"
                },
                anaconda_base = {
                    command = "$FD --fixed-strings anaconda3\\python.exe $HOME\\anaconda3 --full-path -a --color never",
                },
                cwd = {
                    command = "$FD python.exe$ $CWD --full-path --color never -HI",
                },
                workspace = {
                    command = "$FD /bin/python.exe$ $WORKSPACE_PATH --full-path --color never -E /proc -HI",
                }
            }
        end
    }

    local name = vim.loop.os_uname().sysname
    return systems[name] or systems['Linux']
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
    hooks = { hooks.basedpyright_hook, hooks.pyright_hook, hooks.pylance_hook, hooks.pylsp_hook },
    options = {
        debug = false,                             -- switches on/off debug output
        on_telescope_result_callback = nil,        -- callback function for all searches
        on_venv_activate_callback = nil,           -- callback function for after a venv activates
        fd_binary_name = M.find_fd_command_name(), -- plugin looks for `fd` or `fdfind` but you can set something else here
        enable_default_searches = true,            -- switches all default searches on/off
        activate_venv_in_terminal = true,          -- activate the selected python interpreter in terminal windows opened from neovim
        set_environment_variables = true,          -- sets VIRTUAL_ENV or CONDA_PREFIX environment variables
    },
    search = M.get_default_searches()()
}



return M
