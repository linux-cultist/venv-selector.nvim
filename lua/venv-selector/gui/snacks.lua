local gui_utils = require("venv-selector.gui.utils")

local M = {}
M.__index = M

function M.new()
    local self = setmetatable({ results = {}, picker = nil }, M)
    return self
end

function M:pick()
    return Snacks.picker.pick({
        title = "Virtual environments",
        finder = function(opts, ctx)
            return self.results
        end,
        layout = {
            preset = "select",
        },
        format = function(item, picker)
            return {
                { item.icon, gui_utils.hl_active_venv(item) },
                { " " },
                { string.format("%20s", item.source) },
                { "  " },
                { item.name },
            }
        end,
        confirm = function(picker, item)
            if item then
                gui_utils.select(item)
            end
            picker:close()
        end,
    })
end

function M:insert_result(result)
    result.text = result.source .. " " .. result.name
    table.insert(self.results, result)
    if self.picker then
        self.picker:find()
    else
        self.picker = self:pick()
    end
end

function M:search_done()
    self.results = gui_utils.remove_dups(self.results)
    gui_utils.sort_results(self.results)
    self.picker:find()
end

return M
