local gui_utils = require("venv-selector.gui.utils")
local config = require("venv-selector.config")

---@diagnostic disable-next-line: undefined-global
local Snacks = Snacks

local M = {}
M.__index = M

function M.new()
    local self = setmetatable({ results = {}, picker = nil }, M)
    return self
end

function M:pick()
    -- Setup highlight groups for marker color
    local marker_color = config.user_settings.options.selected_venv_marker_color or
        config.user_settings.options.telescope_active_venv_color
    vim.api.nvim_set_hl(0, "VenvSelectMarker", { fg = marker_color })

    local filter_type = config.user_settings.options.picker_filter_type or
        config.user_settings.options.telescope_filter_type or "substring"

    return Snacks.picker.pick({
        title = "Virtual environments",
        matcher = {
            fuzzy = filter_type == "character",
        },
        finder = function(opts, ctx)
            return self.results
        end,
        layout = config.user_settings.options.picker_options.snacks.layout,
        format = function(item, picker)
            local columns = gui_utils.get_picker_columns()
            local hl = gui_utils.hl_active_venv(item)
            local marker_icon = config.user_settings.options.selected_venv_marker_icon or
                config.user_settings.options.icon or "✔"

            -- Prepare column data
            local column_data = {
                marker = hl and { marker_icon, "VenvSelectMarker" } or { " " },
                search_icon = { gui_utils.draw_icons_for_types(item.source) },
                search_name = { string.format("%-15s", item.source) },
                search_result = { item.name }
            }

            -- Build format based on configured column order
            local format_parts = {}
            for i, col in ipairs(columns) do
                if column_data[col] then
                    table.insert(format_parts, column_data[col])
                    -- Add spacing between columns (except after last column)
                    if i < #columns then
                        table.insert(format_parts, { "  " })
                    end
                end
            end

            return format_parts
        end,
        confirm = function(picker, item)
            if item then
                gui_utils.select(item)
            end
            picker:close()
        end,
        on_close = function()
            -- Stop any active search jobs when picker closes
            require("venv-selector.search").stop_search()
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
    if self.picker then
        self.picker:find()
    end
end

return M
