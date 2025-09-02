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

    -- Note: vim.ui.select doesn't support colors, but we can still use configurable columns
    vim.ui.select(self.results, {
        prompt = "Virtual environments",
        format_item = function(result)
            local columns = gui_utils.get_picker_columns()
            local hl = gui_utils.hl_active_venv(result)
            local marker_icon = config.user_settings.options.selected_venv_marker_icon or config.user_settings.options.icon or "✔"
            
            -- Prepare column data (no colors since vim.ui.select doesn't support them)
            local column_data = {
                marker = hl and marker_icon or " ",
                search_icon = gui_utils.draw_icons_for_types(result.source),
                search_name = string.format("%-15s", result.source),
                search_result = result.name
            }
            
            -- Build format based on configured column order
            local parts = {}
            for _, col in ipairs(columns) do
                if column_data[col] then
                    table.insert(parts, column_data[col])
                end
            end
            return table.concat(parts, "  ")
        end,
    }, function(selected_entry)
        gui_utils.select(selected_entry)
    end)
end

return M
