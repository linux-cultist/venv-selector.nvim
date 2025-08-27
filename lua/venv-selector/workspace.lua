local utils = require("venv-selector.utils")
local log = require("venv-selector.logger")

local M = {}

function M.list_folders()
    local workspace_folders = {}

    for _, client in pairs((vim.lsp.get_clients or vim.lsp.get_active_clients)()) do
        if
            vim.tbl_contains({
                "basedpyright",
                "pyright",
                "pylance",
                "pylsp",
            }, client.name)
        then
            for _, folder in pairs(client.workspace_folders or {}) do
                table.insert(workspace_folders, folder.name)
            end
        end
    end

    if utils.table_has_content(workspace_folders) then
        log.debug("Workspace folders: ", workspace_folders)
    else
        log.debug("No workspace folders.")
    end

    return workspace_folders
end

return M
