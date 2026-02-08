-- lua/venv-selector/gui/native.lua
--
-- Native (built-in) picker backend for venv-selector.nvim.
--
-- Responsibilities:
-- - Collect SearchResult entries during the search run.
-- - Present a minimal selection UI using `vim.fn.inputlist`.
-- - Deduplicate and sort results before prompting the user.
--
-- Design notes:
-- - This is the fallback picker when no external picker backend is available.
-- - The UI is intentionally simple: a numbered list showing name and source.
-- - Selection is 1-based (inputlist returns the selected index).
--
-- Conventions:
-- - This module implements the Picker interface used by search.lua:
--   - :insert_result(result)
--   - :search_done()

local gui_utils = require("venv-selector.gui.utils")
local config = require("venv-selector.config")

local M = {}
M.__index = M

---@class venv-selector.NativePickerState
---@field results table[] Accumulated SearchResult-like entries

---Create a new native picker state object.
---@return venv-selector.NativePickerState self
function M.new()
    local self = setmetatable({ results = {} }, M)
    return self
end

---Insert a streamed SearchResult into the picker result list.
---@param result table SearchResult-like table produced by search.lua
function M:insert_result(result)
    table.insert(self.results, result)
end

---Finalize search results, show an inputlist, and activate the selected entry if any.
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