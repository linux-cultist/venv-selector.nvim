-- lua/venv-selector/project_root.lua
--
-- Project root resolution for venv-selector.nvim.
--
-- Responsibilities:
-- - Determine a stable "project root" string for a given buffer.
-- - Prefer LSP-provided root_dir when available (most accurate for complex setups).
-- - Otherwise, fall back to filesystem marker detection via vim.fs.root.
-- - Finally, fall back to the file's directory.
--
-- Notes:
-- - This module intentionally returns a string path (or nil) and does not normalize.
-- - Callers may treat the returned path as a key for caching / LSP scoping.

require("venv-selector.types")

local M = {}

---@type string[]
local DEFAULT_MARKERS = {}

---Try to resolve an LSP root_dir for a buffer.
---If multiple clients are attached, returns the "best" root by picking the longest path.
---(Longest path is a simple heuristic for the most specific root.)
---
---@param bufnr integer
---@return string|nil root_dir
local function lsp_root_for_buf(bufnr)
    local best = nil
    for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
        local r = c.config and c.config.root_dir
        if type(r) == "string" and r ~= "" then
            if not best or #r > #best then
                best = r
            end
        end
    end
    return best
end

---Resolve a project root for a buffer.
---
---Resolution order:
---  1) LSP root_dir for the buffer (if any)
---  2) Filesystem root based on markers (vim.fs.root)
---  3) Directory containing the file (fallback)
---
---@param bufnr? integer Buffer number (defaults to current buffer)
---@param markers? string[] Root marker filenames/dirs (defaults to DEFAULT_MARKERS)
---@return string|nil project_root
function M.for_buf(bufnr, markers)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    markers = markers or DEFAULT_MARKERS

    -- Buffer must exist.
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return nil
    end

    -- Ignore special buffers (help, terminal, etc.).
    if vim.bo[bufnr].buftype ~= "" then
        return nil
    end

    -- Buffer must be associated with a file path.
    local file = vim.api.nvim_buf_get_name(bufnr)
    if not file or file == "" then
        return nil
    end

    local dir = vim.fs.dirname(file)
    if not dir then
        return nil
    end

    -- 1) Prefer LSP root if available.
    local lsp_root = lsp_root_for_buf(bufnr)
    if lsp_root then
        return lsp_root
    end

    -- 2) Try filesystem root detection via markers.
    local fs_root = vim.fs.root(dir, markers)
    if fs_root then
        return fs_root
    end

    -- 3) Fallback: file directory.
    return dir
end

---Alias used by other parts of the plugin.
---Kept for readability at call sites where the root is used as a key.
---
---@param bufnr? integer
---@param markers? string[]
---@return string|nil
function M.key_for_buf(bufnr, markers)
    return M.for_buf(bufnr, markers)
end

return M
