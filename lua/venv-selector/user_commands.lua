local config = require 'venv-selector.config'
local search = require 'venv-selector.search'
local gui = require 'venv-selector.gui'

local M = {}

function M.register()
    vim.api.nvim_create_user_command('VenvSelect', function(opts)
        gui.open(search.search_in_progress)
        search.New(opts)
    end, { nargs = '*', desc = 'Activate venv' })

    vim.api.nvim_create_user_command('VenvSelectLog', function()
        local rc = log.toggle()
        if rc == 1 then
            vim.notify("Please set debug to true in options to use the logger.", vim.log.levels.INFO, { title = 'VenvSelect' })
        end
    end, { desc = "Toggle the VenvSelect log window" })
end

return M
