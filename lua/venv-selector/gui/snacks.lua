local gui_utils = require("venv-selector.gui.utils")
local config = require("venv-selector.config")

---@diagnostic disable-next-line: undefined-global
local Snacks = Snacks

local M = {}
M.__index = M

function M.new()
    return setmetatable({
        results = {},
        picker = nil,
        _refresh_scheduled = false,
        _closed = false,
    }, M)
end

function M:_schedule_refresh()
    if self._closed or self._refresh_scheduled or not self.picker then
        return
    end
    self._refresh_scheduled = true
    vim.defer_fn(function()
        self._refresh_scheduled = false
        if self._closed or not self.picker then
            return
        end

        -- keep selected/active at top while streaming
        self.results = gui_utils.remove_dups(self.results)
        gui_utils.sort_results(self.results)

        self.picker:find()
    end, 80)
end

function M:pick()
    local marker_color = config.user_settings.options.selected_venv_marker_color
    vim.api.nvim_set_hl(0, "VenvSelectMarker", { fg = marker_color })

    local filter_type = config.user_settings.options.picker_filter_type
    local fuzzy = (filter_type == "character")

    self._closed = false

    return Snacks.picker.pick({
        title = "Virtual environments",
        matcher = { fuzzy = fuzzy },
        finder = function()
            return self.results
        end,
        layout = config.user_settings.options.picker_options.snacks.layout,
        format = function(item, _)
            local columns = gui_utils.get_picker_columns()
            local hl = gui_utils.hl_active_venv(item)
            local marker_icon = config.user_settings.options.selected_venv_marker_icon
                or config.user_settings.options.icon
                or "✔"

            local column_data = {
                marker = hl and { marker_icon, "VenvSelectMarker" } or { " " },
                search_icon = { gui_utils.draw_icons_for_types(item.source) },
                search_name = { string.format("%-15s", item.source) },
                search_result = { item.name },
            }

            local parts = {}
            for i, col in ipairs(columns) do
                if column_data[col] then
                    table.insert(parts, column_data[col])
                    if i < #columns then
                        table.insert(parts, { "  " })
                    end
                end
            end
            return parts
        end,
        confirm = function(picker, item)
            if item then
                gui_utils.select(item)
            end
            picker:close()
        end,
        on_close = function()
            self._closed = true
            require("venv-selector.search").stop_search()
            self.picker = nil
        end,
    })
end

function M:insert_result(result)
    result.text = result.source .. " " .. result.name
    table.insert(self.results, result)

    if not self.picker then
        self.picker = self:pick()
        return
    end

    self:_schedule_refresh()
end

function M:search_done()
    self.results = gui_utils.remove_dups(self.results)
    gui_utils.sort_results(self.results)
    if self.picker then
        self.picker:find()
    end
end

return M
