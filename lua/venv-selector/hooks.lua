local lspconfig = require 'lspconfig'

local M = {}

--- @alias NvimLspClient table
--- @alias LspClientCallback fun(client: NvimLspClient): nil
--- @type fun(name: string, callback: LspClientCallback): nil
function M.execute_for_clients(name, callback)
  local dbg = require('venv-selector.utils').dbg
  -- get_active_clients deprecated in neovim v0.10
  local clients = (vim.lsp.get_clients or vim.lsp.get_active_clients) { name = name }

  if not next(clients) then
    dbg('No client named: ' .. name .. ' found')
  else
    vim.tbl_map(callback, clients)
  end
end

--- @type fun(name: string, callback: LspClientCallback): nil
function M.execute_for_client(name, callback)
  local dbg = require('venv-selector.utils').dbg
  -- get_active_clients deprecated in neovim v0.10
  local client = (vim.lsp.get_clients or vim.lsp.get_active_clients)({ name = name })[1]

  if not client then
    dbg('No client named: ' .. name .. ' found')
  else
    callback(client)
  end
end

--- @alias VenvChangedHook fun(venv_path: string, venv_python: string): nil
--- @type VenvChangedHook
function M.pyright_hook(_, venv_python)
  M.execute_for_clients('pyright', function(client)
    client.config.settings =
      vim.tbl_deep_extend('force', client.config.settings, { python = { pythonPath = venv_python } })
    client.notify('workspace/didChangeConfiguration', { settings = nil })
  end)
end

--- @type VenvChangedHook
function M.pylance_hook(_, venv_python)
  M.execute_for_clients('pylance', function(client)
    client.config.settings =
      vim.tbl_deep_extend('force', client.config.settings, { python = { pythonPath = venv_python } })
    client.notify('workspace/didChangeConfiguration', { settings = nil })
  end)
end

--- @type VenvChangedHook
function M.pylsp_hook(venv_path, _)
  local utils = require 'venv-selector.utils'
  local system = require 'venv-selector.system'
  local sys = system.get_info()

  M.execute_for_client('pylsp', function(pylsp)
    local settings = vim.deepcopy(pylsp.config.settings)
    local lib_path = venv_path .. sys.path_sep .. 'lib' .. sys.path_sep
    local site_packages = nil

    for filename, _ in vim.fs.dir(lib_path) do
      if utils.starts_with(filename, 'python') then
        site_packages = lib_path .. sys.path_sep .. filename .. sys.path_sep .. 'site-packages'
      end
    end

    if site_packages == nil then
      utils.dbg('Failed to find site packages directory in: ' .. lib_path)
      return
    end

    lspconfig.pylsp.setup {
      settings = settings,
      before_init = function(_, c)
        local jedi_config = settings.pylsp.plugins.jedi or {}

        if jedi_config.extra_paths ~= nil then
          table.insert(jedi_config.extra_paths, site_packages)
        else
          jedi_config['extra_paths'] = { site_packages }
        end

        c.settings.pylsp.plugins.jedi = jedi_config
      end,
    }
  end)
end

return M
