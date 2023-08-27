local M = {}

-- Connect user command to main function
function M.setup_user_commands(name, callback, desc)
  vim.api.nvim_create_user_command(name, callback, { desc = desc })
end

return M
