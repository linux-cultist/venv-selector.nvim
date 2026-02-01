local gui_utils = require("venv-selector.gui.utils")
local config = require("venv-selector.config")

local M = {}
M.__index = M

function M.new()
    local self = setmetatable({ results = {} }, M)
    return self
end

function M:insert_result(result)
    table.insert(self.results, result)
end

function M:search_done()
  self.results = gui_utils.remove_dups(self.results)
  gui_utils.sort_results(self.results)

  local lines = { "Virtual environments:" }
  for i, r in ipairs(self.results) do
    lines[#lines + 1] = string.format("%d. %s  [%s]", i, r.name, r.source)
  end

  local idx = vim.fn.inputlist(lines)
  local picked = self.results[idx]
  if picked then
    gui_utils.select(picked)
  end
end

return M