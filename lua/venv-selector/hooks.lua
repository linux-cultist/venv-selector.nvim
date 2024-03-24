local M = {}

--- @alias NvimLspClient table
--- @alias LspClientCallback fun(client: NvimLspClient): nil
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

--- @type VenvChangedHook
function M.basedpyright_hook(_, venv_python)
  M.execute_for_client('basedpyright', function(client)
    if client.settings then
      client.settings = vim.tbl_deep_extend('force', client.settings, { python = { pythonPath = venv_python } })
    else
      client.config.settings =
        vim.tbl_deep_extend('force', client.config.settings, { python = { pythonPath = venv_python } })
    end
    client.notify('workspace/didChangeConfiguration', { settings = nil })
  end)
end

--- @alias VenvChangedHook fun(venv_path: string, venv_python: string): nil
--- @type VenvChangedHook
function M.pyright_hook(_, venv_python)
  M.execute_for_client('pyright', function(client)
    if client.settings then
      client.settings = vim.tbl_deep_extend('force', client.settings, { python = { pythonPath = venv_python } })
    else
      client.config.settings =
        vim.tbl_deep_extend('force', client.config.settings, { python = { pythonPath = venv_python } })
    end
    client.notify('workspace/didChangeConfiguration', { settings = nil })
  end)
end

--- @type VenvChangedHook
function M.pylance_hook(_, venv_python)
  M.execute_for_client('pylance', function(client)
    if client.settings then
      client.settings = vim.tbl_deep_extend('force', client.settings, { python = { pythonPath = venv_python } })
    else
      client.config.settings =
        vim.tbl_deep_extend('force', client.config.settings, { python = { pythonPath = venv_python } })
    end
    client.notify('workspace/didChangeConfiguration', { settings = nil })
  end)
end

--- @type VenvChangedHook
function M.pylsp_hook(_, venv_python)
  M.execute_for_client('pylsp', function(client)
    local settings = vim.tbl_deep_extend('force', (client.settings or client.config.settings), {
      pylsp = {
        plugins = {
          jedi = {
            environment = venv_python,
          },
        },
      },
    })
    client.notify('workspace/didChangeConfiguration', { settings = settings })
  end)
end

return M
