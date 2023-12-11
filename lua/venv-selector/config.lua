local system = require 'venv-selector.system'
local hooks = require 'venv-selector.hooks'

local M = {}

M.settings = {}

-- Default settings if user is not setting anything in setup() call
M.default_settings = {
  search = true,
  name = 'venv',
  search_workspace = true,
  search_venv_managers = true,
  parents = 2, -- When search is true, go this many directories up from the current opened buffer
  poetry_path = system.get_venv_manager_default_path 'Poetry',
  pdm_path = system.get_venv_manager_default_path 'PDM',
  pipenv_path = system.get_venv_manager_default_path 'Pipenv',
  pyenv_path = system.get_venv_manager_default_path 'Pyenv',
  anaconda_base_path = system.get_venv_manager_default_path 'AnacondaBase',
  anaconda_envs_path = system.get_venv_manager_default_path 'AnacondaEnvs',
  anaconda = {
    python_parent_dir = nil,
    python_executable = nil,
  },
  venvwrapper_path = system.get_venv_manager_default_path 'VenvWrapper',
  hatch_path = system.get_venv_manager_default_path 'Hatch',
  enable_debug_output = false,
  auto_refresh = false, -- Uses cached results from last search
  fd_binary_name = nil,
  cache_file = system.get_cache_default_path() .. 'venvs.json',
  cache_dir = system.get_cache_default_path(),
  dap_enabled = false,
  notify_user_on_activate = true,
  changed_venv_hooks = { hooks.pyright_hook, hooks.pylance_hook, hooks.pylsp_hook },
}

-- Gets the search path supplied by the user in the setup function, or use current open buffer directory.
function M.get_buffer_dir()
  local dbg = require('venv-selector.utils').dbg
  local path
  if M.settings.path == nil then
    path = require('telescope.utils').buffer_dir()
    dbg('Telescope path: ' .. path)
  -- path = vim.fn.expand("%:p:h")
  -- dbg("Using path from vim.fn.expand: " .. path)
  else
    path = vim.api.nvim_call_function('expand', { M.settings.path })
    dbg('Using path from settings path: ' .. path)
  end
  return path
end

return M
