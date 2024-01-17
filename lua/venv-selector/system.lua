local M = {}

function M.getenv(var)
  local v = os.getenv(var)
  if v == nil then
    return ''
  else
    return v
  end
end

-- Use M.getenv here because env variables like $CONDA_PREFIX doesnt get resolved automatically (but $HOME and ~ does).
M.venv_manager_default_paths = {
  Poetry = {
    Linux = '~/.cache/pypoetry/virtualenvs',
    Darwin = '~/Library/Caches/pypoetry/virtualenvs',
    Windows_NT = M.getenv('APPDATA' .. '\\pypoetry\\virtualenvs'),
  },
  PDM = {
    Linux = '~/.local/share/pdm/venvs',
    Darwin = '~/.local/share/pdm/venvs',
    Windows_NT = M.getenv('APPDATA' .. '\\pdm\\venvs'),
  },
  Pipenv = {
    Linux = '~/.local/share/virtualenvs',
    Darwin = '~/.local/share/virtualenvs',
    Windows_NT = '~\\virtualenvs',
  },
  Pyenv = {
    Linux = '~/.pyenv/versions',
    Darwin = '~/.pyenv/versions',
    Windows_NT = M.getenv 'USERPROFILE' .. '\\.pyenv\\versions',
  },
  Hatch = {
    Linux = '~/.local/share/hatch/env/virtual',
    Darwin = '~/Library/Application/Support/hatch/env/virtual',
    Windows_NT = M.getenv 'USERPROFILE' .. '\\AppData\\Local\\hatch\\env\\virtual',
  },
  VenvWrapper = {
    Linux = '~/.virtualenvs',
    Darwin = '~/.virtualenvs',
    Windows_NT = M.getenv 'USERPROFILE' .. '.virtualenvs', -- VenvWrapper not supported on Windows but need something here
  },
  AnacondaBase = {
    Linux = M.getenv 'CONDA_PREFIX',
    Darwin = M.getenv 'CONDA_PREFIX',
    Windows_NT = M.getenv 'CONDA_PREFIX',
  },
  AnacondaEnvs = {
    Linux = M.getenv 'HOME' .. '/.conda/envs',
    Darwin = M.getenv 'HOME' .. '/.conda/envs',
    Windows_NT = M.getenv 'HOME' .. './conda/envs',
  },
}

M.sysname = vim.loop.os_uname().sysname

function M.get_venv_manager_default_path(venv_manager_name)
  return M.venv_manager_default_paths[venv_manager_name][M.sysname]
end

function M.get_python_parent_path()
  local config = require 'venv-selector.config'
  local parent_dir = config.settings.anaconda.python_parent_dir

  if M.sysname == 'Linux' or M.sysname == 'Darwin' then
    return parent_dir or 'bin'
  else
    return parent_dir or 'Scripts'
  end
end

function M.get_python_name()
  local config = require 'venv-selector.config'
  local python_executable = config.settings.anaconda.python_executable

  if M.sysname == 'Linux' or M.sysname == 'Darwin' then
    return python_executable or 'python'
  else
    return python_executable or 'python.exe'
  end
end

function M.get_path_separator()
  if M.sysname == 'Linux' or M.sysname == 'Darwin' then
    return '/'
  else
    return '\\'
  end
end

function M.get_path_env_separator()
  if M.sysname == 'Windows_NT' then
    return ';'
  else
    return ':'
  end
end

function M.get_cache_default_path()
  if M.sysname == 'Windows_NT' then
    return vim.fn.getenv 'APPDATA' .. '\\venv-selector\\'
  end
  return vim.env.HOME .. '/.cache/venv-selector/'
end

function M.get_info()
  --- @class SystemInfo
  --- @field sysname string System name
  --- @field path_sep string Path separator appropriate for user system
  --- @field path_env_sep string System-specific $PATH entry separator
  --- @field python_name string Name of Python binary
  --- @field python_parent_path string Directory containing Python binary on user system
  return {
    sysname = vim.loop.os_uname().sysname,
    path_sep = M.get_path_separator(),
    path_env_sep = M.get_path_env_separator(),
    python_name = M.get_python_name(),
    python_parent_path = M.get_python_parent_path(),
  }
end

return M
