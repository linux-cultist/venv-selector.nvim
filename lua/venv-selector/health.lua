local M = {}

M.check = function()
    vim.health.start("venv-selector")
    local config = require("venv-selector.config")
    if config.has_legacy_settings then
        vim.health.warn("Legacy settings detected", "Remove the wrapping `settings` key from `setup()` options")
    else
        vim.health.ok("Settings are correct")
    end
end

return M
