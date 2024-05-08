local search = require 'venv-selector.search'
local config = require 'venv-selector.config'
local utils = require 'venv-selector.utils'
dbg = require 'venv-selector.utils'.dbg


local function on_lsp_attach()
    --print("LSP client has successfully attached to the current buffer.")
    local cache = require("venv-selector.cached_venv")
    cache.retrieve()
end

vim.api.nvim_create_autocmd("LspAttach", {
    pattern = "*.py",
    callback = on_lsp_attach,
})


local M = {}

function M.setup(settings)
    config.user_settings = vim.tbl_deep_extend('force', config.default_settings, settings.settings or {})

    vim.api.nvim_create_user_command('VenvSelect', function(opts)
        search.New(opts, config.user_settings)
    end, { nargs = '*', desc = 'Activate venv' })

    vim.api.nvim_create_user_command('VenvSelectCached', function(opts)
        local cache = require("venv-selector.cached_venv")
        cache.retrieve()
    end, { nargs = '*', desc = 'Activate venv from cache' })
end

return M
