local gui_utils = require("venv-selector.gui.utils")

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

    -- TODO: is there any way to add color to the results?
    vim.ui.select(self.results, {
        prompt = "Virtual environments",
        format_item = function(result)
            return gui_utils.format_result_as_string(result.icon, result.source, result.name)
        end,
    }, function(selected_entry)
        gui_utils.select(selected_entry)
    end)
end

return M
