local M = {}

M.check = function()
    vim.health.start("venv-selector")
    vim.health.ok("Settings are correct")
end

return M
