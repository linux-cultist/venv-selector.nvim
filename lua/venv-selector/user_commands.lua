local log = require("venv-selector.logger")
local config = require("venv-selector.config")

local M = {}

function M.register()
    local guiPicker = config.user_settings.options.picker
    if guiPicker == "telescope" then
        vim.api.nvim_create_user_command("VenvSelect", function(opts)
            local gui = require("venv-selector.gui")
            local search = require("venv-selector.fzf_search")
            gui:open(search.search_in_progress)
            search:New(opts)
        end, { nargs = "*", desc = "Activate venv" })
    elseif guiPicker == "fzf-lua" then
        vim.api.nvim_create_user_command("VenvSelect", function(opts)
            local gui = require("venv-selector.gui")
            local search = require("venv-selector.telescope_search")
            gui:open(search.search_in_progress)
            search:New(opts)
        end, { nargs = "*", desc = "Activate venv" })
    else
        vim.notify('Invalid picker setting, please select one of "telescope" or "fzf-lua"', vim.log.levels.ERROR)
        vim.notify("The currently selected picker is: " .. guiPicker, vim.log.levels.ERROR)
    end

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
