
local search = require 'venv-selector.search'
local config = require 'venv-selector.config'


local function on_lsp_attach()
    --print("LSP client has successfully attached to the current buffer.")
    local cache = require("venv-selector.cached_venv")
    cache.retrieve()
end

vim.api.nvim_create_autocmd("LspAttach", {
    pattern = "*.py", -- This could be set to a specific filetype, e.g., '*.lua', if needed
    callback = on_lsp_attach,
})


local M = {}

M.callback = function(filename)
    -- return nil or "" to not include it in search results. Alter the filename how you want before returning.
    return filename:gsub("/bin/python", "")
end

M.workspace_callback = function(filename)
    -- return nil or "" to not include it in search results. Alter the filename how you want before returning.
    return filename:gsub("/bin/python", "")
end


function M.setup(settings)
    vim.api.nvim_create_user_command('VenvSelect', function(opts)
        search.New(opts, config.user_settings)
    end, { nargs = '*', desc = 'Activate venv' })

    vim.api.nvim_create_user_command('VenvSelectCached', function(opts)
        local cache = require("venv-selector.cached_venv")
        cache.retrieve()
    end, { nargs = '*', desc = 'Activate venv from cache' })
end

return M
