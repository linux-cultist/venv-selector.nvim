-- lua/venv-selector/gui/telescope.lua
--
-- Telescope picker backend for venv-selector.nvim.
--
-- Responsibilities:
-- - Present discovered python interpreters (SearchResult) in a Telescope picker.
-- - Provide smartcase filtering with two modes:
--   - substring match (default): prompt must appear as a contiguous substring
--   - character/subsequence match: prompt characters must appear in order
-- - Keep the currently active venv visually pinned near the top by prefix-ranking entries.
-- - Refresh dynamically:
--   - incremental refresh while search jobs stream results
--   - full refresh on search completion (dedup + sort)
--   - auto-refresh on VimResized while the picker is active
-- - Stop any running searches when the Telescope window closes.
--
-- Design notes:
-- - Telescope sorter scoring uses an ordinal prefix ("0 " for active, "1 " otherwise).
--   The scoring_function then incorporates that rank so active entries stay on top.
-- - Display layout (column widths) adapts to vim.o.columns and configured picker columns.
-- - Search results are collected in `self.results` and re-rendered via a new finder.
--
-- Conventions:
-- - `entry.ordinal` is formatted as: "<rank> <name> <source> <path>" for matching/sorting.
-- - `search_opts` are passed through to search.run_search() on manual refresh (<C-r>).
-- - This module implements the Picker interface used by search.lua:
--   - :insert_result(result)
--   - :search_done()

local config = require("venv-selector.config")
local gui_utils = require("venv-selector.gui.utils")

local M = {}
M.__index = M

---Track the active telescope instance so resize events only refresh the visible picker.
---@type any|nil
local active_telescope_instance = nil

---Split the ordinal prefix ("0 " or "1 ") used for active/inactive ranking.
---@param line any
---@return integer rank 0 for active, 1 for others
---@return string rest Remaining string after the prefix
local function split_prefix(line)
    line = tostring(line or "")
    local pfx = line:sub(1, 2) -- "0 " or "1 "
    if pfx == "0 " then return 0, line:sub(3) end
    if pfx == "1 " then return 1, line:sub(3) end
    return 1, line
end

---Prepare prompt/line for smartcase matching:
--- - if prompt contains uppercase letters: use exact case
--- - otherwise: compare lowercased values
---@param prompt string
---@param line string
---@return string p Prepared prompt
---@return string l Prepared line
local function smartcase_prepare(prompt, line)
    line = tostring(line or "")
    if prompt:match("%u") then
        return prompt, line
    end
    return prompt:lower(), line:lower()
end

---Create a Telescope sorter that performs smartcase substring matching.
---Scores by:
--- - rank (active first)
--- - first substring match position
---@return any sorter Telescope sorter instance
local function make_smartcase_substring_sorter()
    local sorters = require("telescope.sorters")
    return sorters.new {
        scoring_function = function(_, prompt, line)
            local rank, raw = split_prefix(line)

            if not prompt or prompt == "" then
                return rank -- active (0) before others (1)
            end

            local p, l = smartcase_prepare(prompt, raw)
            local start = l:find(p, 1, true)
            if not start then return -1 end

            -- Active bias: keep active entries grouped ahead of others.
            return (rank * 1000000) + start
        end,
        highlighter = function() return {} end,
    }
end

---Create a Telescope sorter that performs smartcase subsequence (character) matching.
---Scores by:
--- - rank (active first)
--- - first matched character position
--- - compactness (span) of the match (smaller span is better)
---@return any sorter Telescope sorter instance
local function make_smartcase_subsequence_sorter()
    local sorters = require("telescope.sorters")
    return sorters.new {
        scoring_function = function(_, prompt, line)
            local rank, raw = split_prefix(line)

            if not prompt or prompt == "" then
                return rank
            end

            local p, l = smartcase_prepare(prompt, raw)

            local pos, first = 1, nil
            for i = 1, #p do
                local ch = p:sub(i, i)
                local found = l:find(ch, pos, true)
                if not found then return -1 end
                first = first or found
                pos = found + 1
            end

            local last = pos - 1
            local span = last - (first or 1)

            return (rank * 1000000) + (first or 1) + (span * 0.01)
        end,
        highlighter = function() return {} end,
    }
end

---Compute a layout_config based on the current editor dimensions.
---This keeps the Telescope window readable across small/large terminals.
---@return table layout_config
local function get_dynamic_layout_config()
    local columns = vim.o.columns
    local _lines = vim.o.lines

    -- Calculate dynamic width (80-95% of terminal width, with min/max constraints)
    local width_ratio = 0.9
    local min_width = 60
    local max_width = 120
    local dynamic_width = math.max(min_width, math.min(max_width, math.floor(columns * width_ratio)))

    -- Calculate dynamic height (30-50% of terminal height, with min/max constraints)
    local height_ratio = 0.4
    local min_height = 0.3
    local max_height = 0.6
    local dynamic_height = math.max(min_height, math.min(max_height, height_ratio))

    return {
        height = dynamic_height,
        width = dynamic_width,
        prompt_position = "top",
    }
end

---Compute a Telescope entry_display configuration based on the current width and configured columns.
---@return table display_config
local function get_dynamic_display_config()
    local columns = vim.o.columns
    local picker_columns = gui_utils.get_picker_columns()

    -- Calculate dynamic widths based on configured columns
    local name_width, source_width

    -- Reserve space for icon columns (2 chars each) and separators
    local reserved_space = 6 -- 2 (icon) + 2 (type icon) + 2 (separators)
    local available_space = columns - reserved_space

    if columns < 80 then
        -- Very small screens: prioritize name, minimal source
        name_width = math.floor(available_space * 0.75)
        source_width = math.floor(available_space * 0.25)
    elseif columns < 120 then
        -- Small-medium screens: balanced distribution
        name_width = math.floor(available_space * 0.65)
        source_width = math.floor(available_space * 0.35)
    else
        -- Large screens: cap name width, give more to source
        name_width = math.min(90, math.floor(available_space * 0.6))
        source_width = math.min(30, math.floor(available_space * 0.4))
    end

    -- Ensure minimum readable widths
    name_width = math.max(20, name_width)
    source_width = math.max(8, source_width)

    -- Build display config based on column order
    local items = {}
    for _, col in ipairs(picker_columns) do
        if col == "marker" then
            table.insert(items, { width = 2 })
        elseif col == "search_icon" then
            table.insert(items, { width = 2 })
        elseif col == "search_name" then
            table.insert(items, { width = source_width })
        elseif col == "search_result" then
            table.insert(items, { width = name_width })
        end
    end

    -- Add remaining space for the last column
    if #items > 0 then
        items[#items].remaining = true
    end

    return {
        separator = " ",
        items = items,
    }
end

---Choose the appropriate sorter based on the configured filter type.
---@return any sorter Telescope sorter instance
local function get_sorter()
    local filter_type = config.get_user_options().picker_filter_type

    require("venv-selector.logger").debug(filter_type)

    if filter_type == "character" then
        return make_smartcase_subsequence_sorter()
    end

    return make_smartcase_substring_sorter()
end

---Create and display a Telescope picker that streams results from the search layer.
---@param search_opts table Search options passed through to search.run_search() on manual refresh
---@return table self Picker instance implementing :insert_result and :search_done
function M.new(search_opts)
    local self = setmetatable({ results = {} }, M)

    -- Set this as the active instance for resize handling
    active_telescope_instance = self

    -- Setup highlight groups for marker color
    local marker_color = config.user_settings.options.selected_venv_marker_color

    -- Create marker highlight group
    vim.api.nvim_set_hl(0, "VenvSelectMarker", { fg = marker_color })

    local opts = {
        prompt_title = "Virtual environments (ctrl-r to refresh)",
        finder = self:make_finder(),
        layout_strategy = "vertical",
        layout_config = get_dynamic_layout_config(),
        cwd = require("telescope.utils").buffer_dir(),

        sorting_strategy = "ascending",
        sorter = get_sorter(),
        selection_strategy = "reset",
        multi_selection = false,
        attach_mappings = function(bufnr, map)
            map({ "i", "n" }, "<cr>", function()
                local selected_entry = require("telescope.actions.state").get_selected_entry()
                gui_utils.select(selected_entry)
                require("telescope.actions").close(bufnr)
            end)

            map("i", "<C-r>", function()
                self.results = {}
                require("venv-selector.search").run_search(self, search_opts)
            end)

            -- Disable multi-selection mappings
            map("i", "<Tab>", false)
            map("i", "<S-Tab>", false)
            map("n", "<Tab>", false)
            map("n", "<S-Tab>", false)

            return true
        end,
    }

    -- Create the picker
    local picker = require("telescope.pickers").new({}, opts)

    -- Set up autocmd to stop search when telescope window closes
    local augroup = vim.api.nvim_create_augroup("VenvSelectTelescope", { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
        group = augroup,
        callback = function(ev)
            -- Check if the closed window is the telescope prompt
            local winid = tonumber(ev.match)
            if winid and picker and picker.prompt_bufnr then
                local closed_bufnr = vim.api.nvim_win_get_buf(winid)
                if closed_bufnr == picker.prompt_bufnr then
                    active_telescope_instance = nil
                    require("venv-selector.search").stop_search()
                    vim.api.nvim_del_augroup_by_id(augroup)
                end
            end
        end,
    })

    picker:find()

    -- Set up autocmd for window resize
    self:setup_resize_autocmd()

    return self
end

---Create a Telescope finder for the current `self.results` table.
---This recreates the entry_display config each time so column widths track window size.
---@return any finder Telescope finder
function M:make_finder()
    local display_config = get_dynamic_display_config()
    local displayer = require("telescope.pickers.entry_display").create(display_config)

    local entry_maker = function(entry)
        local _icon = entry.icon
        entry.value = entry.name
        local is_active = gui_utils.hl_active_venv(entry) ~= nil
        local prefix = is_active and "0 " or "1 "

        entry.ordinal = prefix .. table.concat({
            tostring(entry.name or ""),
            tostring(entry.source or ""),
            tostring(entry.path or ""),
        }, " ")

        entry.display = function(e)
            local picker_columns = gui_utils.get_picker_columns()

            -- Prepare column data
            local hl = gui_utils.hl_active_venv(entry)
            local marker_icon = config.user_settings.options.selected_venv_marker_icon or
                config.user_settings.options.icon or "●"

            -- Use pre-created highlight groups
            local marker_hl = hl and "VenvSelectMarker" or nil

            local column_data = {
                marker = {
                    hl and marker_icon or " ",
                    marker_hl,
                },
                search_icon = {
                    gui_utils.draw_icons_for_types(entry.source),
                },
                search_name = {
                    e.source,
                },
                search_result = { e.name },
            }

            -- Build display items based on configured column order
            local display_items = {}
            for _, col in ipairs(picker_columns) do
                if column_data[col] then
                    table.insert(display_items, column_data[col])
                end
            end

            return displayer(display_items)
        end

        return entry
    end

    return require("telescope.finders").new_table({
        results = self.results,
        entry_maker = entry_maker,
    })
end

---Refresh Telescope picker layout and finder to reflect the current results and window size.
function M:update_results()
    local bufnr = vim.api.nvim_get_current_buf()
    local picker = require("telescope.actions.state").get_current_picker(bufnr)
    if picker ~= nil then
        -- Update layout configuration for new window size
        picker.layout_config = get_dynamic_layout_config()
        picker:full_layout_update()
        -- Then refresh the finder with new column widths
        picker:refresh(self:make_finder(), { reset_prompt = false })
    end
end

---Insert a streamed SearchResult into the picker and schedule a refresh.
---Refresh is debounced to avoid excessive UI updates while jobs stream results.
---@param result table SearchResult-like table: {name, path, icon, source, type}
function M:insert_result(result) -- result is a table with name, path, icon, source, venv.
    table.insert(self.results, result)

    if self._refresh_scheduled then
        return
    end
    self._refresh_scheduled = true

    vim.defer_fn(function()
        self._refresh_scheduled = false

        -- self.results = gui_utils.remove_dups(self.results)
        -- gui_utils.sort_results(self.results)

        self:update_results()
    end, 30) -- 20–50ms is usually fine
end

---Finalize search results (deduplicate + sort) and refresh the picker display.
function M:search_done()
    self.results = gui_utils.remove_dups(self.results)
    gui_utils.sort_results(self.results)

    self:update_results()
end

---Install an autocmd that refreshes the picker layout on VimResized while this instance is active.
function M:setup_resize_autocmd()
    -- Create autocmd group for this telescope instance
    local group = vim.api.nvim_create_augroup("VenvSelectorTelescope", { clear = true })

    -- Set up autocmd for VimResized event
    vim.api.nvim_create_autocmd("VimResized", {
        group = group,
        callback = function()
            -- Only refresh if this telescope instance is still active
            if active_telescope_instance == self then
                -- Small delay to ensure resize is complete
                vim.defer_fn(function()
                    if active_telescope_instance == self then
                        self:update_results()
                    end
                end, 50)
            else
                -- Clean up autocmd if instance is no longer active
                vim.api.nvim_del_augroup_by_id(group)
            end
        end,
    })
end

return M
