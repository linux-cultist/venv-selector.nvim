-- events.lua (bus)
local M = {}
local GROUP = vim.api.nvim_create_augroup("venv_selector.events", { clear = false })

function M.on(event, cb, opts)
  opts = opts or {}
  opts.group = GROUP
  opts.pattern = event
  opts.callback = function(args) cb(args) end
  return vim.api.nvim_create_autocmd("User", opts)
end

function M.emit(event, data)
  vim.schedule(function()
    vim.api.nvim_exec_autocmds("User", { pattern = event, data = data, modeline = false })
  end)
end


return M
