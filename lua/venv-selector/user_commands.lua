local M = {}

-- Check if Neovim version is 0.11 or higher
local function check_nvim_version()
    local version = vim.version()
    if version.major == 0 and version.minor < 11 then
        vim.notify(
            "venv-selector.nvim requires Neovim 0.11+. Current version: " .. 
            version.major .. "." .. version.minor .. "." .. version.patch,
            vim.log.levels.ERROR,
            { title = "VenvSelect" }
        )
        return false
    end
    return true
end

function M.register()
    vim.api.nvim_create_user_command("VenvSelect", function(opts)
        if not check_nvim_version() then return end
        
        local gui = require("venv-selector.gui")
        gui.open(opts)
    end, { nargs = "*", desc = "Activate venv" })

    vim.api.nvim_create_user_command("VenvSelectLog", function()
        local log = require("venv-selector.logger")
        local rc = log.toggle()
        if rc == 1 then
            vim.notify("Please set debug to true in options to use the logger.", vim.log.levels.INFO, {
                title = "VenvSelect",
            })
        end
    end, { desc = "Toggle the VenvSelect log window" })

    -- Move config require here too
    local config = require("venv-selector.config")
    if config.user_settings.options.cached_venv_automatic_activation == false then
        vim.api.nvim_create_user_command("VenvSelectCached", function()
            local cache = require("venv-selector.cached_venv")
            cache.retrieve()
        end, { nargs = "*", desc = "Activate cached venv for the current cwd" })
    end
end

return M
