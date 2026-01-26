local gui_utils = require("venv-selector.gui.utils")
local config = require("venv-selector.config")

local M = {}
M.__index = M

local H = {}

-- Create a namespace for extmarks
-- This is used to highlight the active virtual environment in the results
H.ns_id = vim.api.nvim_create_namespace("MiniPickVenvSelect")

function M.new()
    local self = setmetatable({ results = {}, picker_started = false }, M)

    -- Setup highlight groups for marker color
    local marker_color = config.user_settings.options.selected_venv_marker_color or
        config.user_settings.options.telescope_active_venv_color
    vim.api.nvim_set_hl(0, "VenvSelectMarker", { fg = marker_color })

    return self
end


local function item_to_text(item)
    local columns = gui_utils.get_picker_columns()
    local marker_icon = config.user_settings.options.selected_venv_marker_icon
        or config.user_settings.options.icon or "✔"

    local hl = gui_utils.hl_active_venv(item)
    local column_data = {
        marker = hl and marker_icon or " ",
        search_icon = gui_utils.draw_icons_for_types(item.source),
        search_name = string.format("%-15s", item.source),
        search_result = item.name,
    }

    local parts = {}
    for _, col in ipairs(columns) do
        if column_data[col] then table.insert(parts, column_data[col]) end
    end
    return table.concat(parts, "  ")
end

function M:insert_result(result)
    result.text = result.text or item_to_text(result)
    table.insert(self.results, result)

    local mini_pick = require("mini.pick")

    if not self.picker_started then
        self.picker_started = true
        -- optional: sort even before first start (cheap)
        self.results = gui_utils.remove_dups(self.results)
        gui_utils.sort_results(self.results)
        self:start_picker()
        return
    end

    if mini_pick.is_picker_active() then
        -- keep active/selected at top while results stream in
        self.results = gui_utils.remove_dups(self.results)
        gui_utils.sort_results(self.results)
        mini_pick.set_picker_items(self.results)
    end
end

function M:search_done()
    self.results = gui_utils.remove_dups(self.results)
    gui_utils.sort_results(self.results) -- marker sorting handled here

    local mini_pick = require("mini.pick")
    if mini_pick.is_picker_active() then
        mini_pick.set_picker_items(self.results)
    elseif not self.picker_started then
        self:start_picker()
    end
end

local function apply_marker_hl(buf_id, items_arr)
    pcall(vim.api.nvim_buf_clear_namespace, buf_id, H.ns_id, 0, -1)

    local columns = gui_utils.get_picker_columns()
    local marker_icon = config.user_settings.options.selected_venv_marker_icon
        or config.user_settings.options.icon or "✔"

    for i, item in ipairs(items_arr) do
        if gui_utils.hl_active_venv(item) then
            local column_data = {
                marker = marker_icon,
                search_icon = gui_utils.draw_icons_for_types(item.source),
                search_name = string.format("%-15s", item.source),
                search_result = item.name,
            }

            local marker_col = 0
            for _, col in ipairs(columns) do
                if col == "marker" then break end
                if column_data[col] then
                    marker_col = marker_col + vim.fn.strwidth(column_data[col]) + 2
                end
            end

            pcall(vim.api.nvim_buf_set_extmark, buf_id, H.ns_id, i - 1, marker_col, {
                end_col = marker_col + vim.fn.strwidth(marker_icon),
                hl_group = "VenvSelectMarker",
            })
        end
    end
end


function M:start_picker()
    local mini_pick = require("mini.pick")

    mini_pick.start({
        source = {
            name = "Virtual environments",
            items = self.results,

            -- matching behavior
            match = mini_pick.default_match,

            -- keep fuzzy highlighting, add marker highlighting
            show = function(buf_id, items_arr, query)
                mini_pick.default_show(buf_id, items_arr, query)
                apply_marker_hl(buf_id, items_arr)
            end,

            choose = function(item)
                gui_utils.select(item)
            end,
        },
    })
end

return M
