-- lua/venv-selector/gui/mini-pick.lua
--
-- mini.pick picker backend for venv-selector.nvim.
--
-- Responsibilities:
-- - Present discovered python interpreters (SearchResult) in a mini.pick picker.
-- - Support two filter modes controlled by options.picker_filter_type:
--   - "character": use mini.pick default fuzzy matching (subsequence-like)
--   - "substring": use an exact contiguous substring filter
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
-- Design notes:
-- - mini.pick expects items to be arbitrary tables; it renders from item.text (or a show() function).
-- - In substring mode we bypass default_show() so we can:
--   - render from item.text ourselves
--   - apply both marker highlight and match-range highlight
-- - `mini_pick.set_picker_items()` + `mini_pick.refresh()` updates an active picker in-place.
--
-- Conventions:
-- - Items passed from search.lua are SearchResult-like tables: {name, path, icon, type, source}.
-- - We populate `item.text` with a formatted line for matching and rendering.
-- - This module implements the Picker interface used by search.lua:
--   - :insert_result(result)
--   - :search_done()

local gui_utils = require("venv-selector.gui.utils")
local config = require("venv-selector.config")

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
---@param item table SearchResult-like item
---@return string text
local function item_to_text(item)
    local icon = marker_icon()
    local marker = gui_utils.hl_active_venv(item) and icon or " "
    local src_icon = gui_utils.draw_icons_for_types(item.source)
    local src_name = string.format("%-15s", item.source)
    return table.concat({ marker, src_icon, src_name, item.name }, "  ")
end

-- ============================================================================
-- Show / match helpers
-- ============================================================================

---Character/fuzzy mode:
---Use MiniPick.default_match + MiniPick.default_show and add marker highlighting.
---@param buf_id integer
---@param items table[]
---@param query string[]
local function show_with_marker_hl_default(buf_id, items, query)
    local mini_pick = require("mini.pick")
    mini_pick.default_show(buf_id, items, query)

    vim.api.nvim_buf_clear_namespace(buf_id, NS, 0, -1)

    local icon = marker_icon()
    local icon_bytes = #icon

    for i, item in ipairs(items) do
        if gui_utils.hl_active_venv(item) then
            vim.api.nvim_buf_add_highlight(buf_id, NS, "VenvSelectMarker", i - 1, 0, icon_bytes)
        end
    end
end

---Substring mode:
---Exact contiguous substring filter. mini.pick already applies ignorecase/smartcase adjustments
---to the string table it passes in, so we can compare directly.
---@param stritems string[] Rendered strings for each item index
---@param inds integer[] Candidate indices
---@param query string[] Query characters
---@return integer[] filtered_inds
local function match_substring(stritems, inds, query)
    local q = table.concat(query)
    if q == "" then return inds end

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
---@param items table[]
---@param query string[]
local function show_with_marker_hl_substring(buf_id, items, query)
    -- render lines from item.text (or fallback)
    local lines = vim.tbl_map(function(item)
        item.text = item.text or item_to_text(item)
        return item.text
    end, items)

    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
    vim.api.nvim_buf_clear_namespace(buf_id, NS, 0, -1)

    local icon = marker_icon()
    local icon_bytes = #icon
    local q = table.concat(query)

    -- Best-effort case behavior mirroring ignorecase/smartcase.
    local ignorecase = vim.o.ignorecase
    local smartcase = vim.o.smartcase
    local case_insensitive = ignorecase and (not smartcase or q:lower() == q)
    local q_cmp = case_insensitive and q:lower() or q

    for i, item in ipairs(items) do
        local line = lines[i]

        -- marker highlight
        if gui_utils.h_
