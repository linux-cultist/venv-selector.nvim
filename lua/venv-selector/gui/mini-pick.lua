local gui_utils = require("venv-selector.gui.utils")
local config = require("venv-selector.config")

local M = {}
M.__index = M

local NS = vim.api.nvim_create_namespace("VenvSelectMiniPick")

local function marker_icon()
    return config.user_settings.options.selected_venv_marker_icon or "✔"
end

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

-- Character/fuzzy mode (uses MiniPick.default_match + MiniPick.default_show)
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

-- Substring mode: exact contiguous substring filter + highlighting
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

    -- do a best-effort case behavior mirroring ignorecase/smartcase
    local ignorecase = vim.o.ignorecase
    local smartcase = vim.o.smartcase
    local case_insensitive = ignorecase and (not smartcase or q:lower() == q)
    local q_cmp = case_insensitive and q:lower() or q

    for i, item in ipairs(items) do
        local line = lines[i]

        -- marker highlight
        if gui_utils.hl_active_venv(item) then
            vim.api.nvim_buf_add_highlight(buf_id, NS, "VenvSelectMarker", i - 1, 0, icon_bytes)
        end

        -- substring highlight
        if q_cmp ~= "" then
            local line_cmp = case_insensitive and line:lower() or line
            local s, e = line_cmp:find(q_cmp, 1, true)
            if s then
                -- MiniPick uses this group for matched ranges
                vim.api.nvim_buf_add_highlight(buf_id, NS, "MiniPickMatchRanges", i - 1, s - 1, e)
            end
        end
    end
end

function M.new(opts)
    local self = setmetatable({}, M)
    self.results = {}
    self.picker_started = false

    self.refresh_ms = 80
    self._refresh_scheduled = false

    local marker_color = config.user_settings.options.selected_venv_marker_color
    vim.api.nvim_set_hl(0, "VenvSelectMarker", { fg = marker_color })
    return self
end

local function push_to_picker(results)
    local mini_pick = require("mini.pick")
    if not mini_pick.is_picker_active() then return end
    mini_pick.set_picker_items(results)
    mini_pick.refresh()
end

function M:_schedule_push()
    if self._refresh_scheduled then return end
    self._refresh_scheduled = true

    vim.defer_fn(function()
        self._refresh_scheduled = false
        self.results = gui_utils.remove_dups(self.results)
        gui_utils.sort_results(self.results)
        push_to_picker(self.results)
    end, self.refresh_ms)
end

function M:insert_result(result)
    result.text = result.text or item_to_text(result)
    self.results[#self.results + 1] = result

    if not self.picker_started then
        self.picker_started = true
        self:start_picker()
        return
    end

    self:_schedule_push()
end

function M:search_done()
    self.results = gui_utils.remove_dups(self.results)
    gui_utils.sort_results(self.results)
    push_to_picker(self.results)
end

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
            name   = "Virtual environments",
            items  = self.results,
            match  = use_substring and match_substring or nil, -- nil => MiniPick.default_match()
            show   = use_substring and show_with_marker_hl_substring or show_with_marker_hl_default,
            choose = function(item)
                gui_utils.select(item)
            end,
        },
    })
end

return M
