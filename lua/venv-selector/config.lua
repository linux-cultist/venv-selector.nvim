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
                    command = "$FD python$ ~/.local/share/hatch --color never -E '*-build*' -E /proc"
                },
                poetry = {
                    command = "$FD /bin/python$ ~/.cache/pypoetry/virtualenvs --full-path"
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
                    command = "$FD /bin/python$ $CWD --full-path --color never -E /proc -I -a",
                },
                workspace = {
                    command = "$FD /bin/python$ $WORKSPACE_PATH --full-path --color never -E /proc -HI -a",
                },
                file = {
                    command = "$FD /bin/python$ $FILE_PATH --full-path --color never -E /proc -HI -a",
                }
            }
        end,
        ['Darwin'] = function()
            return {
                virtualenvs = {
                    command = "$FD python$ ~/.virtualenvs --color never -E /proc"
                },
                hatch = {
                    command =
                    "$FD python$ ~/Library/Application/Support/hatch/env/virtual --color never -E '*-build*' -E /proc"
                },
                poetry = {
                    command = "$FD /bin/python$ ~/Library/Caches/pypoetry/virtualenvs --full-path"
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
                    command = "$FD /bin/python$ $CWD --full-path --color never -E /proc -I -a",
                },
                workspace = {
                    command = "$FD /bin/python$ $WORKSPACE_PATH --full-path --color never -E /proc -HI -a",
                },
                file = {
                    command = "$FD /bin/python$ $FILE_PATH --full-path --color never -E /proc -HI -a",
                }
            }
        end,
        ['Windows_NT'] = function()
            -- NOTE: In lua, '\' is an escape character. So in windows paths, we need 4 slashes where there normally would be 2 slashes on the command line.
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
                    command = "$FD python.exe$ $HOME/anaconda3/envs --full-path -a -E Lib",
                    type = "anaconda"
                },
                anaconda_base = {
                    command = "$FD anaconda3\\\\python.exe $HOME/anaconda3 --full-path -a --color never",
                    type = "anaconda"
                },
                cwd = {
                    command = "$FD Scripts\\\\python.exe$ $CWD --full-path --color never -I -a",
                },
                workspace = {
                    command = "$FD Scripts\\\\python.exe$ $WORKSPACE_PATH --full-path --color never -HI -a",
                },
                file = {
                    command = "$FD Scripts\\\\python.exe$ $FILE_PATH --full-path --color never -HI -a",
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

M.on_telescope_result_callback = function(filename)
    local system = M.user_settings.detected.system
    if system == "Linux" or system == "Darwin" then
        return filename:gsub("/bin/python", "")
    else
        return filename:gsub("\\Scripts\\python.exe", "")
    end
end

M.default_settings = {
    cache = {
        file = "~/.cache/venv-selector/venvs2.json",
    },
    hooks = { hooks.basedpyright_hook, hooks.pyright_hook, hooks.pylance_hook, hooks.pylsp_hook },
    options = {
        debug = false,                                                 -- switches on/off debug output
        on_telescope_result_callback = M.on_telescope_result_callback, -- callback function for all searches
        on_venv_activate_callback = nil,                               -- callback function for after a venv activates
        fd_binary_name = M.find_fd_command_name(),                     -- plugin looks for `fd` or `fdfind` but you can set something else here
        enable_default_searches = true,                                -- switches all default searches on/off
        activate_venv_in_terminal = true,                              -- activate the selected python interpreter in terminal windows opened from neovim
        set_environment_variables = true,                              -- sets VIRTUAL_ENV or CONDA_PREFIX environment variables
    },
    search = M.get_default_searches()()
}



return M
