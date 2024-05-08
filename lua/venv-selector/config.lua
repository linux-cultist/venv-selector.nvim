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
                pypoetry = {
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
                    command = "fd '/bin/python$' $WORKSPACE_PATH --full-path --color never -E /proc --unrestricted",
                }
            }
        end,
        ['Windows_NT'] = function()
            return {
                --virtualenvs = {
                --    command = "fd 'python$' ~\\.virtualenvs --color never"
                --},
                --hatch = {
                --    command = "fd 'python$' ~\\.local\\share\\hatch --color never"
                --},
                --pypoetry = {
                --    command = "fd 'versions\\([0-9.]+)\\bin\\python.exe$' ~\\.pyenv\\versions --full-path --color never"
                --},
                --anaconda_envs = {
                --    command = "fd 'Scripts\\python.exe$' ~\\.conda\\envs --full-path --color never"
                --},
                --anaconda_base = {
                --    command = "fd '\\python$' \\opt\\anaconda\\bin --full-path --color never",
                --},
                --cwd = {
                --    command = "fd '\\Scripts\\python.exe$' $CWD --full-path --color never",
                --},
                --workspace = {
                --    command = "fd '\\Scripts\\python.exe$' $WORKSPACE_PATH --full-path --color never --unrestricted",
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
                pypoetry = {
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
                    command = "fd '/bin/python$' $WORKSPACE_PATH --full-path --color never -E /proc --unrestricted",
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
