local config = require("venv-selector.config")
local gui = require("venv-selector.gui")
local log = require("venv-selector.logger")

local M = {}

function M.register()
    vim.api.nvim_create_user_command("VenvSelect", function(opts)
        gui.open(opts)
    end, { nargs = "*", desc = "Activate venv" })

    vim.api.nvim_create_user_command("VenvSelectLog", function()
        local rc = log.toggle()
        if rc == 1 then
            vim.notify("Please set debug to true in options to use the logger.", vim.log.levels.INFO, {
                title = "VenvSelect",
            })
        end
    end, { desc = "Toggle the VenvSelect log window" })

    if config.user_settings.options.cached_venv_automatic_activation == false then
        vim.api.nvim_create_user_command("VenvSelectCached", function()
            local cache = require("venv-selector.cached_venv")
            cache.retrieve()
        end, {
            nargs = "*",
            desc = "Activate cached venv for the current cwd",
        })
    end
end

return M
