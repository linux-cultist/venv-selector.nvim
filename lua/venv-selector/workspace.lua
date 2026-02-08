-- lua/venv-selector/workspace.lua
--
-- Workspace folder discovery for venv-selector.nvim.
--
-- Responsibilities:
-- - Collect workspace folder roots from active LSP clients that support Python.
-- - Provide a stable list of unique folder paths (strings) for searches such as:
--     search.workspace -> $WORKSPACE_PATH substitution
--
-- Design notes:
-- - LSP clients can be global (vim.lsp.get_clients()) or buffer-scoped
--   (vim.lsp.get_clients({bufnr=...})).
-- - A client is treated as "python-supporting" if:
--     - its configured filetypes include "python", OR
--     - it is attached to at least one python buffer.
-- - Workspace folders are deduplicated by `folder.name` (as used by Neovim’s LSP API).

local M = {}

---Return true if an LSP client should be considered "python-supporting".
---
---Heuristics:
--- 1) Client config declares `filetypes` including "python"
--- 2) Client is attached to at least one python buffer
---
---@param client vim.lsp.Client
---@return boolean ok
local function supports_python(client)
    -- Method 1: Check configured filetypes.
    ---@cast client +{config: {filetypes: string[]}}
    local filetypes = client.config and client.config.filetypes or {}
    if vim.tbl_contains(filetypes, "python") then
        return true
    end

    -- Method 2: Check if attached to any Python buffers.
    local attached_buffers = client.attached_buffers or {}
    for buf_id, _ in pairs(attached_buffers) do
        if vim.api.nvim_buf_is_valid(buf_id) and vim.bo[buf_id].filetype == "python" then
            return true
        end
    end

    return false
end

---List unique workspace folder roots from python-supporting LSP clients.
---
---If `bufnr` is provided, only consider LSP clients attached to that buffer;
---otherwise consider all clients.
---
---@param bufnr? integer Optional buffer number to scope LSP client selection
---@return string[] folders Workspace folder roots (unique)
function M.list_folders(bufnr)
    local utils = require("venv-selector.utils")
    local log = require("venv-selector.logger")

    ---@type string[]
    local workspace_folders = {}

    ---@type table<string, true>
    local seen_folders = {}

    -- Use buffer-specific clients if bufnr provided.
    ---@type vim.lsp.Client[]
    local clients = bufnr and vim.lsp.get_clients({ bufnr = bufnr }) or vim.lsp.get_clients()

    for _, client in pairs(clients) do
        if supports_python(client) then
            log.debug("Found Python-supporting LSP: " .. client.name)

            for _, folder in pairs(client.workspace_folders or {}) do
                -- Neovim represents folders as {name=..., uri=...} in many configs.
                -- This code uses folder.name as the path key.
                if folder and folder.name and not seen_folders[folder.name] then
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
