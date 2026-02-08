-- lua/venv-selector/gui/snacks.lua
--
-- Snacks picker backend for venv-selector.nvim.
--
-- Responsibilities:
-- - Present discovered python interpreters (SearchResult) in a Snacks picker.
-- - Configure matching mode based on picker_filter_type:
--   - "character" => fuzzy matching enabled
--   - otherwise   => non-fuzzy substring-like matching
-- - Stream results into the picker as they arrive and refresh the UI with debouncing.
-- - Keep active/selected environments at the top while streaming by deduping + sorting on refresh.
-- - Stop running searches when the picker closes.
--
-- Design notes:
-- - Snacks requires each item to have a `text` field used for matching; we synthesize it from
--   "<source> <name>" so filtering naturally narrows on both.
-- - Refresh is scheduled (debounced) to avoid excessive `picker:find()` calls while results stream.
-- - `self.picker` is created lazily on first result to avoid opening an empty picker.
--
-- Conventions:
-- - This module implements the Picker interface used by search.lua:
--   - :insert_result(result)
--   - :search_done()

require("venv-selector.types")

local gui_utils = require("venv-selector.gui.utils")
local config = require("venv-selector.config")

---@diagnostic disable-next-line: undefined-global
local Snacks = Snacks

local M = {}
M.__index = M


---Create a new Snacks picker state object.
---@return venv-selector.SnacksPickerState self
function M.new()
    ---@type venv-selector.SnacksPickerState
    return setmetatable({
        results = {},
        picker = nil,
        _refresh_scheduled = false,
        _closed = false,
    }, M)
end

---Schedule a debounced refresh of the picker UI.
---While streaming results, we keep active entries at the top by deduping + sorting on refresh.
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

---Create and show the Snacks picker.
---The picker reads from `self.results` via the finder callback.
---@return any picker Snacks picker instance
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

---Insert a streamed SearchResult into the picker.
---Opens the picker on the first result, then refreshes (debounced) as more arrive.
---@param result venv-selector.SearchResult SearchResult produced by search.lua
function M:insert_result(result)
    ---@type venv-selector.SnacksItem
    local item = result
    item.text = item.source .. " " .. item.name
    table.insert(self.results, item)

    if not self.picker then
        self.picker = self:pick()
        return
    end

    self:_schedule_refresh()
end

---Finalize search results (deduplicate + sort) and refresh the picker display.
function M:search_done()
    self.results = gui_utils.remove_dups(self.results)
    gui_utils.sort_results(self.results)
    if self.picker then
        self.picker:find()
    end
end

return M
