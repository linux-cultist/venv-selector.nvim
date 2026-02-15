-- lua/venv-selector/gui/mini-pick.lua
--
-- mini.pick picker backend for venv-selector.nvim.
--
-- Responsibilities:
-- - Present discovered python interpreters (SearchResult) in a mini.pick picker.
-- - Support two filter modes controlled by options.picker_filter_type:
--   - "character": use mini.pick default fuzzy matching (subsequence-like)
--   - "substring": use an exact contiguous substring filter + range highlighting
-- - Render a multi-column display line with:
--   - selected/active marker
--   - search source icon
--   - search source name
--   - environment name
-- - Highlight:
--   - active marker using "VenvSelectMarker"
--   - matched substring ranges in substring mode using "MiniPickMatchRanges"
-- - Stream results into the picker and refresh with debouncing to avoid UI churn.
-- - Stop running searches when the picker closes (MiniPickStop event).
--
-- Conventions:
-- - Items produced by search.lua are venv-selector.SearchResult tables.
-- - This backend may augment each item with an optional `text` field used for matching/rendering.
-- - This module implements the Picker interface used by search.lua:
--   - :insert_result(result)
--   - :search_done()

local gui_utils = require("venv-selector.gui.utils")
local config = require("venv-selector.config")

-- Load shared annotations/types.
require("venv-selector.types")

local M = {}
M.__index = M

---Namespace used for marker/match highlights in the mini.pick buffer.
local NS = vim.api.nvim_create_namespace("VenvSelectMiniPick")

---Return the configured marker icon (or a default).
---@return string icon
local function marker_icon()
    return config.user_settings.options.selected_venv_marker_icon or "✔"
end

---Convert an item to a display/match string for mini.pick.
---@param item venv-selector.SearchResult
---@return string text
local function item_to_text(item)
    local columns = gui_utils.get_picker_columns()
    local icon = marker_icon()

    local column_data = {
        marker = gui_utils.hl_active_venv(item) and icon or " ",
        search_icon = gui_utils.draw_icons_for_types(item.source),
        search_name = string.format("%-15s", item.source),
        search_result = item.name,
    }

    local parts = {}
    for _, col in ipairs(columns) do
        local v = column_data[col]
        if v then
            parts[#parts + 1] = v
        end
    end
    return table.concat(parts, "  ")
end

-- ============================================================================
-- Show / match helpers
-- ============================================================================

---Character/fuzzy mode:
---Use mini.pick default_show and add marker highlighting.
---@param buf_id integer
---@param items venv-selector.SearchResult[]
---@param query string[]
local function show_with_marker_hl_default(buf_id, items, query)
    local mini_pick = require("mini.pick")
    mini_pick.default_show(buf_id, items, query)

    vim.api.nvim_buf_clear_namespace(buf_id, NS, 0, -1)

    local icon = marker_icon()
    local icon_bytes = #icon

    for i, item in ipairs(items) do
        if gui_utils.hl_active_venv(item) then
            vim.api.nvim_buf_set_extmark(buf_id, NS, i - 1, 0, {
                end_col = icon_bytes,
                hl_group = "VenvSelectMarker",
            })
        end
    end
end

---Substring mode matcher:
---Exact contiguous substring filter. mini.pick already applies ignorecase/smartcase adjustments
---to the string table it passes in, so we can compare directly.
---@param stritems string[] Rendered strings for each item index
---@param inds integer[] Candidate indices
---@param query string[] Query characters
---@return integer[] filtered_inds
local function match_substring(stritems, inds, query)
    local q = table.concat(query)
    if q == "" then
        return inds
    end

    local out = {}
    for _, i in ipairs(inds) do
        -- stritems/query are already case-adjusted by mini.pick (ignorecase/smartcase)
        if stritems[i]:find(q, 1, true) ~= nil then
            out[#out + 1] = i
        end
    end
    return out
end

---Substring mode renderer:
---Render item.text lines, then apply:
--- - marker highlight
--- - substring match-range highlight (best-effort mirror of ignorecase/smartcase)
---@param buf_id integer
---@param items venv-selector.SearchResult[]
---@param query string[]
local function show_with_marker_hl_substring(buf_id, items, query)
    -- render lines from item.text (or fallback)
    local lines = vim.tbl_map(function(item)
        item.text = item.text or item_to_text(item)
        return item.text
    end, items)

    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(buf_id, NS, 0, -1)

    local icon_bytes = #marker_icon()
    local q = table.concat(query)

    -- Best-effort case behavior mirroring ignorecase/smartcase.
    local ignorecase = vim.o.ignorecase
    local smartcase = vim.o.smartcase
    local case_insensitive = ignorecase and (not smartcase or q:lower() == q)
    local q_cmp = case_insensitive and q:lower() or q

    for i, item in ipairs(items) do
        local line = lines[i]

        -- marker highlight
        if gui_utils.hl_active_venv(item) then
            vim.api.nvim_buf_set_extmark(buf_id, NS, i - 1, 0, {
                end_col = icon_bytes,
                hl_group = "VenvSelectMarker",
            })
        end

        -- substring highlight
        if q_cmp ~= "" then
            local line_cmp = case_insensitive and line:lower() or line
            local s, e = line_cmp:find(q_cmp, 1, true)
            if s then
                vim.api.nvim_buf_set_extmark(buf_id, NS, i - 1, s - 1, {
                    end_col = e,
                    hl_group = "MiniPickMatchRanges",
                })
            end
        end
    end
end

-- ============================================================================
-- Picker state (typed via venv-selector.types.lua)
-- ============================================================================

---Create a new mini.pick picker state object.
---@param opts table|nil Unused, kept for API parity with other backends
---@return venv-selector.MiniPickState self
function M.new(opts)
    ---@type venv-selector.MiniPickState
    local self = setmetatable({}, M)
    self.results = {}
    self.picker_started = false
    self.refresh_ms = 80
    self._refresh_scheduled = false

    local marker_color = config.user_settings.options.selected_venv_marker_color
    vim.api.nvim_set_hl(0, "VenvSelectMarker", { fg = marker_color })
    return self
end

---Push new items into an active mini.pick instance.
---@param results venv-selector.SearchResult[]
local function push_to_picker(results)
    local mini_pick = require("mini.pick")
    if not mini_pick.is_picker_active() then
        return
    end
    mini_pick.set_picker_items(results)
    mini_pick.refresh()
end

---Schedule a debounced push to mini.pick (dedupe + sort + refresh).
---@param self venv-selector.MiniPickState
function M:_schedule_push()
    if self._refresh_scheduled then
        return
    end
    self._refresh_scheduled = true

    vim.defer_fn(function()
        self._refresh_scheduled = false
        self.results = gui_utils.remove_dups(self.results)
        gui_utils.sort_results(self.results)
        push_to_picker(self.results)
    end, self.refresh_ms)
end

---Insert a streamed SearchResult into the picker.
---@param self venv-selector.MiniPickState
---@param result venv-selector.SearchResult
function M:insert_result(result)
    ---@type venv-selector.MiniPickItem
    local item = vim.tbl_extend("force", {}, result, {
        text = item_to_text(result),
    })

    self.results[#self.results + 1] = item

    if not self.picker_started then
        self.picker_started = true
        self:start_picker()
        return
    end

    self:_schedule_push()
end

---Finalize search results (dedupe + sort) and refresh the picker display.
---@param self venv-selector.MiniPickState
function M:search_done()
    self.results = gui_utils.remove_dups(self.results)
    gui_utils.sort_results(self.results)
    push_to_picker(self.results)
end

---Start the mini.pick UI bound to the current results list.
---@param self venv-selector.MiniPickState
function M:start_picker()
    local mini_pick = require("mini.pick")

    local marker_color = config.user_settings.options.selected_venv_marker_color
    vim.api.nvim_set_hl(0, "VenvSelectMarker", { fg = marker_color })

    vim.api.nvim_create_autocmd("User", {
        pattern = "MiniPickStop",
        once = true,
        callback = function()
            require("venv-selector.search").stop_search()
        end,
    })

    local filter_type = config.user_settings.options.picker_filter_type -- "substring"|"character"
    local use_substring = (filter_type == "substring")

    mini_pick.start({
        source = {
            name = "Virtual environments",
            items = self.results,
            match = use_substring and match_substring or nil, -- nil => MiniPick.default_match()
            show = use_substring and show_with_marker_hl_substring or show_with_marker_hl_default,
            choose = function(item)
                ---@cast item venv-selector.SearchResult
                gui_utils.select(item)
            end,
        },
    })
end

return M
