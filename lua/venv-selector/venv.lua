local system = require 'venv-selector.system'
local utils = require 'venv-selector.utils'
local dbg = require('venv-selector.utils').dbg
local mytelescope = require 'venv-selector.mytelescope'
local config = require 'venv-selector.config'

local M = {}

M.current_python_path = nil -- Contains path to current python if activated, nil otherwise
M.current_venv = nil -- Contains path to current venv folder if activated, nil otherwise
M.current_bin_path = nil -- Keeps track of old system path so we can remove it when adding a new one
M.fd_handle = nil
M.path_to_search = nil

function M.load(action)
  local act = action or {}

  local ready_for_new_search = M.fd_handle == nil or M.fd_handle:is_closing() == true
  if ready_for_new_search == false then
    dbg 'Cannot start a new search while old one is running.'
    return
  end

  local buffer_dir = config.get_buffer_dir()

  -- Only search for parent venvs if search option is true
  if config.settings.search == true then
    if act.force_refresh == true then
      if M.path_to_search == nil then
        dbg 'No previous search path when asked to refresh results.'
        M.path_to_search = utils.find_parent_dir(buffer_dir, config.settings.parents)
        M.find_parent_venvs(M.path_to_search)
      else
        dbg('User refreshed results - buffer_dir is: ' .. buffer_dir)
        M.path_to_search = utils.find_parent_dir(buffer_dir, config.settings.parents)
        M.find_parent_venvs(M.path_to_search)
      end
    else
      M.path_to_search = utils.find_parent_dir(buffer_dir, config.settings.parents)
      M.find_parent_venvs(M.path_to_search)
    end
  else
    M.find_other_venvs()
  end
end

-- This gets called as soon as the parent venv search is done.
function M.find_other_venvs(event)
  event = event or {}
  if config.settings.search_workspace == true then
    M.find_workspace_venvs()
  end

  if config.settings.search_venv_managers == true then
    M.find_venv_manager_venvs()
  end

  mytelescope.show_results()
end

-- Manages the paths to python since they are different on Linux, Mac and Windows
-- systems. The user selects the virtual environment to use in the Telescope picker,
-- but inside the virtual environment, the actual python and its parent directory name
-- differs between Linux, Mac and Windows. This function sets up the correct full path
-- to python, adds it to the system path and sets the VIRTUAL_ENV variable.
function M.set_venv_and_system_paths(venv_row)
  dbg 'Getting local system info...'
  local sys = system.get_info()
  dbg(sys)
  local venv_path = venv_row.value
  local new_bin_path
  local venv_python

  if sys.python_parent_path:len() == 0 then
    -- If we dont have a python_parent_path (user may have set it to an empty string), use just the venv_path
    new_bin_path = venv_path
    venv_python = new_bin_path .. sys.path_sep .. sys.python_name
  else
    new_bin_path = venv_path .. sys.path_sep .. sys.python_parent_path
    venv_python = new_bin_path .. sys.path_sep .. sys.python_name
  end

  -- Make sure our python exists on disk before activating it, in case paths are wrong
  if vim.fn.executable(venv_python) == 0 then
    utils.notify("The python path '" .. venv_python .. "' doesnt exist.")
    return
  end

  if config.settings.dap_enabled == true then
    M.setup_dap_venv(venv_python)
  end

  if config.settings.notify_user_on_activate == true then
    utils.notify("Activated '" .. venv_python .. "'")
  end

  for _, hook in ipairs(config.settings.changed_venv_hooks) do
    hook(venv_path, venv_python)
  end

  local current_system_path = vim.fn.getenv 'PATH'
  local prev_bin_path = M.current_bin_path

  -- Remove previous bin path from path
  if prev_bin_path ~= nil then
    current_system_path = string.gsub(current_system_path, utils.escape_pattern(prev_bin_path .. sys.path_env_sep), '')
  end

  -- Add new bin path to path
  local new_system_path = new_bin_path .. sys.path_env_sep .. current_system_path
  vim.fn.setenv('PATH', new_system_path)
  M.current_bin_path = new_bin_path

  -- Set VIRTUAL_ENV
  -- Set CONDA_PREFIX instead if we are on Windows and a conda environment is activated
  if vim.fn.has("win32") then
    local venv_path_std = string.gsub(venv_path, '/', '\\')
    local conda_base_path_std = string.gsub(config.settings.anaconda_base_path, '/', '\\')
    local conda_envs_path_std = string.gsub(config.settings.anaconda_envs_path, '/', '\\')
    local is_conda_base = string.find(venv_path_std, conda_base_path_std)
    local is_conda_env = string.find(venv_path, conda_envs_path_std)
    if is_conda_base == 1 or is_conda_env == 1 then
      vim.fn.setenv('CONDA_PREFIX', venv_path)
    else
      vim.fn.setenv('VIRTUAL_ENV', venv_path)
    end
  else
    vim.fn.setenv('VIRTUAL_ENV', venv_path)
  end

  M.current_python_path = venv_python
  M.current_venv = venv_path
  dbg 'Finished setting venv and system paths.'
end

function M.deactivate_venv()
  -- Remove previous bin path from path
  local current_system_path = vim.fn.getenv 'PATH'
  local prev_bin_path = M.current_bin_path

  if prev_bin_path ~= nil then
    local sys = system.get_info()
    current_system_path = string.gsub(current_system_path, utils.escape_pattern(prev_bin_path .. sys.path_env_sep), '')
    vim.fn.setenv('PATH', current_system_path)
  end

  -- Remove VIRTUAL_ENV environment variable.
  vim.fn.setenv('VIRTUAL_ENV', nil)

  -- TODO: Set pyright to use system python if it exists.
  -- Not sure how to do this in a cross platform compatible way.

  M.current_python_path = nil
  M.current_venv = nil
end

-- Start a search for venvs in all directories under the nstart_dir
-- Async function to search for venvs - it will call VS.show_results() when its done by itself.
function M.find_parent_venvs(parent_dir)
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)
  if stdout == nil or stderr == nil then
    dbg 'Failed to create pipes for fd process.'
    return
  end

  local venv_names = utils.create_fd_venv_names_regexp(config.settings.name)
  local fdconfig = {
    args = { '--absolute-path', '--color', 'never', '-E', '/proc', '-HItd', venv_names, parent_dir },
    stdio = { nil, stdout, stderr },
  }

  if config.settings.anaconda_base_path:len() > 0 then
    table.insert(fdconfig, '-E')
    table.insert(fdconfig, config.settings.anaconda_base_path)
  end

  if config.settings.anaconda_envs_path:len() > 0 then
    table.insert(fdconfig, '-E')
    table.insert(fdconfig, config.settings.anaconda_envs_path)
  end

  dbg("Looking for parent venvs in '" .. parent_dir .. "' using the following parameters:")
  dbg(fdconfig.args)

  M.fd_handle = vim.loop.spawn(
    config.settings.fd_binary_name,
    fdconfig,
    vim.schedule_wrap(function() -- on exit
      stdout:read_stop()
      stderr:read_stop()
      stdout:close()
      stderr:close()
      M.find_other_venvs()
      M.fd_handle:close()
    end)
  )
  vim.loop.read_start(stdout, mytelescope.on_read)
end

-- Gets called when user hits enter in the Telescope results dialog
function M.activate_venv()
  local actions_state = require 'telescope.actions.state'

  local selected_venv = actions_state.get_selected_entry()
  if selected_venv ~= nil and selected_venv.value ~= nil then
    dbg('User selected venv in telescope: ' .. selected_venv.value)
    M.set_venv_and_system_paths(selected_venv)
    M.cache_venv(selected_venv)
  end
end

function M.list_pyright_workspace_folders()
  local workspace_folders = {}
  local workspace_folders_found = false
  for _, client in pairs((vim.lsp.get_clients or vim.lsp.get_active_clients)()) do
    if vim.tbl_contains({ 'pyright', 'pylance' }, client.name) then
      for _, folder in pairs(client.workspace_folders or {}) do
        dbg('Found workspace folder: ' .. folder.name)
        table.insert(workspace_folders, folder.name)
        workspace_folders_found = true
      end
    end
  end
  if workspace_folders_found == false then
    dbg 'No workspace folders found'
  end

  return workspace_folders
end

-- Look for workspace venvs
function M.find_workspace_venvs()
  local workspace_folders = M.list_pyright_workspace_folders()
  local search_path_string = utils.create_fd_search_path_string(workspace_folders)
  if search_path_string:len() ~= 0 then
    local search_path_regexp = utils.create_fd_venv_names_regexp(config.settings.name)
    local cmd = config.settings.fd_binary_name
      .. " -HItd --absolute-path --color never '"
      .. search_path_regexp
      .. "' "
      .. search_path_string
    dbg('Running search for workspace venvs with: ' .. cmd)
    local openPop = assert(io.popen(cmd, 'r'))
    mytelescope.add_lines(openPop:lines(), 'Workspace')
    openPop:close()
  else
    dbg 'Found no workspaces to search for venvs.'
  end
end

-- Look for Poetry and Pipenv managed venv directories and search them.
function M.find_venv_manager_venvs()
  local paths = {
    config.settings.poetry_path,
    config.settings.pdm_path,
    config.settings.pipenv_path,
    config.settings.pyenv_path,
    config.settings.hatch_path,
    config.settings.venvwrapper_path,
    config.settings.anaconda_envs_path,
  }
  local search_path_string = utils.create_fd_search_path_string(paths)
  if search_path_string:len() ~= 0 then
    local cmd = config.settings.fd_binary_name
      .. ' . -HItd -tl --absolute-path --max-depth 1 --color never '
      .. search_path_string
      .. " --exclude '3.*.*'"
    dbg('Running search for venv manager venvs with: ' .. cmd)
    local openPop = assert(io.popen(cmd, 'r'))
    mytelescope.add_lines(openPop:lines(), 'VenvManager')
    openPop:close()

    -- If $CONDA_PREFIX is defined and exists, add the path as an existing venv
    if vim.fn.isdirectory(config.settings.anaconda_base_path) ~= 0 then
      table.insert(
        mytelescope.results,
        { icon = '', path = utils.remove_last_slash(config.settings.anaconda_base_path .. '/') }
      )
    end
  else
    dbg 'Found no venv manager directories to search for venvs.'
  end
end

function M.setup_dap_venv(venv_python)
  require('dap-python').resolve_python = function()
    return venv_python
  end
end

function M.retrieve_from_cache()
  if vim.fn.filereadable(config.settings.cache_file) == 1 then
    local cache_file = vim.fn.readfile(config.settings.cache_file)
    if cache_file ~= nil and cache_file[1] ~= nil then
      local venv_cache = vim.fn.json_decode(cache_file[1])
      if venv_cache ~= nil and venv_cache[vim.fn.getcwd()] ~= nil then
        M.set_venv_and_system_paths(venv_cache[vim.fn.getcwd()])
        return
      end
    end
  end
end

function M.cache_venv(venv)
  local venv_cache = {
    [vim.fn.getcwd()] = { value = venv.value },
  }

  if vim.fn.filewritable(config.settings.cache_file) == 0 then
    vim.fn.mkdir(vim.fn.expand(config.settings.cache_dir), 'p')
  end

  local venv_cache_json = nil

  if vim.fn.filereadable(config.settings.cache_file) == 1 then
    -- if cache file exists and is not empty read it and merge it with the new cache
    local cached_file = vim.fn.readfile(config.settings.cache_file)
    if cached_file ~= nil and cached_file[1] ~= nil then
      local cached_json = vim.fn.json_decode(cached_file[1])
      local merged_cache = vim.tbl_deep_extend('force', cached_json, venv_cache)
      venv_cache_json = vim.fn.json_encode(merged_cache)
    end
  else
    venv_cache_json = vim.fn.json_encode(venv_cache)
  end
  vim.fn.writefile({ venv_cache_json }, config.settings.cache_file)
end

return M
