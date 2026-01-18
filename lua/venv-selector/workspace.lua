local M = {}

---@param client vim.lsp.Client
---@return boolean
local function supports_python(client)
    -- Method 1: Check configured filetypes
    ---@cast client +{config: {filetypes: string[]}}
    local filetypes = client.config and client.config.filetypes or {}
    if vim.tbl_contains(filetypes, "python") then
        return true
    end

    -- Method 2: Check if attached to any Python buffers
    local attached_buffers = client.attached_buffers or {}
    for buf_id, _ in pairs(attached_buffers) do
        if vim.api.nvim_buf_is_valid(buf_id) and vim.bo[buf_id].filetype == "python" then
            return true
        end
    end

    return false
end


---@param bufnr? integer
---@return string[]
function M.list_folders(bufnr)
    local utils = require("venv-selector.utils")
    local log = require("venv-selector.logger")

    local workspace_folders = {}
    local seen_folders = {}

    -- Use buffer-specific clients if bufnr provided
    local clients = bufnr and vim.lsp.get_clients({ bufnr = bufnr }) or vim.lsp.get_clients()

    for _, client in pairs(clients) do
        if supports_python(client) then
            log.debug("Found Python-supporting LSP: " .. client.name)
            for _, folder in pairs(client.workspace_folders or {}) do
                if not seen_folders[folder.name] then
                    seen_folders[folder.name] = true
                    table.insert(workspace_folders, folder.name)
                end
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
