local hooks = require 'venv-selector.hooks'
local log = require 'venv-selector.logger'

local M = {}

M.user_settings = {}

function M.get_default_searches()
  local systems = {
    ['Linux'] = function()
      return {
        virtualenvs = {
          command = "$FD 'python$' ~/.virtualenvs --color never -E /proc",
        },
        hatch = {
          command = "$FD 'python$' ~/.local/share/hatch --color never -E '*-build*' -E /proc",
        },
        poetry = {
          command = "$FD '/bin/python$' ~/.cache/pypoetry/virtualenvs --full-path",
        },
        pyenv = {
          command = "$FD '/bin/python$' ~/.pyenv/versions --full-path --color never -E /proc -E pkgs/ -E envs/ -L",
        },
        anaconda_envs = {
          command = "$FD 'bin/python$' ~/.conda/envs --full-path --color never -E /proc",
          type = 'anaconda',
        },
        anaconda_base = {
          command = "$FD '/python$' /opt/anaconda/bin --full-path --color never -E /proc",
          type = 'anaconda',
        },
        miniconda_envs = {
          command = "$FD 'bin/python$' ~/miniconda3/envs --full-path --color never -E /proc",
          type = 'miniconda',
        },
        miniconda_base = {
          command = "$FD '/python$' ~/miniconda3/bin --full-path --color never -E /proc",
          type = 'miniconda',
        },
        pipx = {
          command = "$FD '/bin/python$' ~/.local/share/pipx/venvs ~/.local/pipx/venvs --full-path --color never -E /proc",
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
    ['Darwin'] = function()
      return {
        virtualenvs = {
          command = "$FD 'python$' ~/.virtualenvs --color never -E /proc",
        },
        hatch = {
          command = "$FD 'python$' ~/Library/Application\\\\ Support/hatch/env/virtual --color never -E '*-build*' -E /proc",
        },
        poetry = {
          command = "$FD '/bin/python$' ~/Library/Caches/pypoetry/virtualenvs --full-path",
        },
        pyenv = {
          command = "$FD '/bin/python$' ~/.pyenv/versions --full-path --color never -E /proc -E pkgs/ -E envs/ -L",
        },
        anaconda_envs = {
          command = "$FD 'bin/python$' ~/.conda/envs --full-path --color never -E /proc",
          type = 'anaconda',
        },
        anaconda_base = {
          command = "$FD '/python$' /opt/anaconda/bin --full-path --color never -E /proc",
          type = 'anaconda',
        },
        pipx = {
          command = "$FD '/bin/python$' ~/.local/share/pipx/venvs ~/.local/pipx/venvs --full-path --color never -E /proc",
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
    ['Windows_NT'] = function()
      -- NOTE: In lua, '\' is an escape character. So in windows paths, we need 4 slashes where there normally would be 2 slashes on the command line.
      return {
        hatch = {
          command = '$FD python.exe $HOME/AppData/Local/hatch/env/virtual --full-path --color never',
        },
        poetry = {
          command = '$FD python.exe$ $HOME/AppData/Local/pypoetry/Cache/virtualenvs --full-path --color never',
        },
        pyenv = {
          command = '$FD python.exe$ $HOME/.pyenv/pyenv-win/versions $HOME/.pyenv-win-venv/envs -E Lib',
        },
        anaconda_envs = {
          command = '$FD python.exe$ $HOME/anaconda3/envs --full-path -a -E Lib',
          type = 'anaconda',
        },
        anaconda_base = {
          command = '$FD anaconda3\\\\python.exe $HOME/anaconda3 --full-path -a --color never',
          type = 'anaconda',
        },
        pipx = {
          command = 'fd Scripts\\\\python.exe $HOME/pipx/venvs --full-path -a --color never',
        },
        cwd = {
          command = '$FD Scripts\\\\python.exe$ $CWD --full-path --color never -HI -a -L',
        },
        workspace = {
          command = '$FD Scripts\\\\python.exe$ $WORKSPACE_PATH --full-path --color never -HI -a -L',
        },
        file = {
          command = '$FD Scripts\\\\python.exe$ $FILE_DIR --full-path --color never -HI -a -L',
        },
      }
    end,
  }

  local name = vim.loop.os_uname().sysname
  return systems[name] or systems['Linux']
end

function M.merge_user_settings(user_settings)
  log.debug('User plugin settings: ', user_settings.settings, '')
  M.user_settings = vim.tbl_deep_extend('force', M.default_settings, user_settings.settings or {})

  M.user_settings.detected = {
    system = vim.loop.os_uname().sysname,
  }
  log.debug('Complete user settings:', M.user_settings, '')
end

function M.find_fd_command_name()
  local look_for = { 'fd', 'fdfind', 'fd_find' }
  for _, cmd in ipairs(look_for) do
    if vim.fn.executable(cmd) == 1 then
      return cmd
    end
  end
end

M.default_settings = {
  cache = {
    file = '~/.cache/venv-selector/venvs2.json',
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

    -- telescope viewer options
    on_telescope_result_callback = nil, -- callback function for modifying telescope results
    show_telescope_search_type = true, -- Shows which of the searches found which venv in telescope
    telescope_filter_type = 'substring', -- When you type something in telescope, filter by "substring" or "character"
  },
  search = M.get_default_searches()(),
}

return M
