local M = require('lualine.component'):extend()

local default_opts = {
  icon = '',
  color = { fg = '#CDD6F4' },
  on_click = function()
    require('venv-selector').open()
  end,
}

function M:init(options)
  options = vim.tbl_deep_extend('keep', options or {}, default_opts)
  M.super.init(self, options)
end

function M:update_status()
  local venv = require('venv-selector').get_active_venv()
  if venv then
    local venv_parts = vim.fn.split(venv, '/')
    local venv_name = venv_parts[#venv_parts]
    return venv_name
  else
    return 'Select Venv'
  end
end

return M
