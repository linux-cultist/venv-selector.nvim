local hooks = require 'venv-selector.hooks'


local M = {}

M.user_settings = {}

M.default_settings = {
    cache = {
        file = "~/.cache/venv-selector/venvs2.json",
    },
    hooks = { hooks.basedpyright_hook, hooks.pyright_hook, hooks.pylance_hook, hooks.pylsp_hook },
    workspace = {
        command = "fd 'venv/bin/python$' $WORKSPACE_PATH --full-path --color never -E /proc -I",
        callback = M.workspace_callback
    },
    cwd = {
        command = "fd 'venv/bin/python$' $CWD --full-path --color never -E /proc -I",
        callback = M.callback
    },
    search = {
        {
            name = "My venvs",
            command = "fd '/venv/bin/python$' ~/Code --full-path --color never -E /proc",
            callback = M.callback
        },
        {
            name = "Virtualenvs",
            command = "fd 'python$' ~/.virtualenvs --color never -E /proc"
        },
        {
            name = "Hatch",
            command = "fd 'python$' ~/.local/share/hatch --color never -E /proc"
        },
        {
            name = "Pypoetry",
            command = "fd 'versions/([0-9.]+)/bin/python$' ~/.pyenv/versions --full-path --color never -E /proc",
        },
        {
            name = "Anaconda Envs",
            command = "fd 'bin/python$' ~/.conda/envs --full-path --color never -E /proc"
        },
        {
            name = "Anaconda Base",
            command = "fd '/python$' /opt/anaconda/bin --full-path --color never -E /proc",
        },
    }
}


return M
