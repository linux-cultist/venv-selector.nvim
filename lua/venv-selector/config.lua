local hooks = require 'venv-selector.hooks'


local M = {}

M.user_settings = {}

M.default_settings = {
    cache = {
        file = "~/.cache/venv-selector/venvs2.json",
    },
    hooks = { hooks.basedpyright_hook, hooks.pyright_hook, hooks.pylance_hook, hooks.pylsp_hook },
    settings = {
        enable_debug_output = false
    },
    search = {
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
            command = "fd '/bin/python$' $WORKSPACE_PATH --full-path --color never -E /proc -I",
        }
    }
}


return M
