local M = {}


function M.execute_for_client(name, callback)
    -- get_active_clients deprecated in neovim v0.10
    local client = (vim.lsp.get_clients or vim.lsp.get_active_clients)({ name = name })[1]

    if not client then
        --print('No client named: ' .. name .. ' found')
    else
        callback(client)
    end
end

function M.basedpyright_hook(venv_python)
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

function M.pyright_hook(venv_python)
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

function M.pylance_hook(venv_python)
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

function M.pylsp_hook(venv_python)
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
