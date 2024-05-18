--local log = require("venv-selector.logger")

M = {}

function M.list_folders()
    local workspace_folders = {}

    for _, client in pairs((vim.lsp.get_clients or vim.lsp.get_active_clients)()) do
        dbg(client.name, "client name")
        if vim.tbl_contains({ 'basedpyright', 'pyright', 'pylance', 'pylsp' }, client.name) then
            for _, folder in pairs(client.workspace_folders or {}) do
                table.insert(workspace_folders, folder.name)
            end
        end
    end

    return workspace_folders
end

return M
