local M = {}

local DEFAULT_MARKERS = {}

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

function M.for_buf(bufnr, markers)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    markers = markers or DEFAULT_MARKERS

    if not vim.api.nvim_buf_is_valid(bufnr) then
        return nil
    end

    if vim.bo[bufnr].buftype ~= "" then
        return nil
    end

    local file = vim.api.nvim_buf_get_name(bufnr)
    if not file or file == "" then
        return nil
    end

    local dir = vim.fs.dirname(file)
    if not dir then
        return nil
    end

    -- 1) Prefer LSP root if available
    local lsp_root = lsp_root_for_buf(bufnr)
    if lsp_root then
        return lsp_root
    end

    -- 2) Try filesystem root detection via markers
    local fs_root = vim.fs.root(dir, markers)
    if fs_root then
        return fs_root
    end

    -- 3) Fallback: file directory
    return dir
end



function M.key_for_buf(bufnr, markers)
    return M.for_buf(bufnr, markers)
end

return M
