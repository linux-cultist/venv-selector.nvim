local hooks = require 'venv-selector.hooks'


local M = {}

M.user_settings = {}

function M.get_default_searches()
    local systems = {
        ['Darwin'] = function()
            return {
                virtualenvs = {
                    command = "fd 'python$' ~/.virtualenvs --color never -E /proc"
                },
                hatch = {
                    command = "fd 'python$' ~/.local/share/hatch --color never -E /proc"
                },
                pyenv = {
                    command = "fd 'versions/([0-9.]+)/bin/python$' ~/.pyenv/versions --full-path --color never -E /proc"
                },
                anaconda_envs = {
                    command = "fd 'bin/python$' ~/.conda/envs --full-path --color never -E /proc"
                },
                anaconda_base = {
                    command = "fd '/python$' /opt/anaconda/bin --full-path --color never -E /proc",
                },
                cwd = {
                    command = "fd '/bin/python$' $CWD --full-path --color never -E /proc",
                },
                workspace = {
                    command = "fd '/bin/python$' $WORKSPACE_PATH --full-path --color never -E /proc -I",
                }
            }
        end,
        ['Windows_NT'] = function()
            return {
                hatch = {
                    command = "fd python.exe $HOME/AppData/Local/hatch/env/virtual --full-path --color never"
                },
                poetry = {
                    command = "fd python.exe$ $HOME/AppData/Local/pypoetry/Cache/virtualenvs --full-path --color never"
                },
                anaconda_envs = {
                    command = "fd python.exe$ $HOME/anaconda3/envs --full-path -a -E Lib"
                },
                anaconda_base = {
                    command = "fd --fixed-strings anaconda3\\python.exe $HOME\\anaconda3 --full-path -a --color never",
                },
                cwd = {
                    command = "fd python.exe$ $CWD --full-path --color never",
                },
                --workspace = {
                --    command = "fd '\\Scripts\\python.exe$' $WORKSPACE_PATH --full-path --color never -I",
                --}
            }
        end,
        ['default'] = function()
            return {
                virtualenvs = {
                    command = "fd 'python$' ~/.virtualenvs --color never -E /proc"
                },
                hatch = {
                    command = "fd 'python$' ~/.local/share/hatch --color never -E /proc"
                },
                pyenv = {
                    command = "fd 'versions/([0-9.]+)/bin/python$' ~/.pyenv/versions --full-path --color never -E /proc"
                },
                anaconda_envs = {
                    command = "fd 'bin/python$' ~/.conda/envs --full-path --color never -E /proc"
                },
                anaconda_base = {
                    command = "fd '/python$' /opt/anaconda/bin --full-path --color never -E /proc",
                },
                cwd = {
                    command = "fd '/bin/python$' $CWD --full-path --color never -E /proc",
                },
                workspace = {
                    command = "fd '/bin/python$' $WORKSPACE_PATH --full-path --color never -E /proc -I",
                }
            }
        end
    }

    local name = vim.loop.os_uname().sysname
    return systems[name] or systems['default']
end

M.default_settings = {
    cache = {
        file = "~/.cache/venv-selector/venvs2.json",
    },
    hooks = { hooks.basedpyright_hook, hooks.pyright_hook, hooks.pylance_hook, hooks.pylsp_hook },
    options = {
        debug = false
    },
    search = M.get_default_searches()()
}


return M
