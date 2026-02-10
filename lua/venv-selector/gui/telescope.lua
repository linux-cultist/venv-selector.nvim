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
-- Conventions:
-- - `entry.ordinal` is formatted as: "<rank> <name> <source> <path>" for matching/sorting.
-- - This module implements the Picker interface used by search.lua:
--   - :insert_result(result)
--   - :search_done()

local config = require("venv-selector.config")
local gui_utils = require("venv-selector.gui.utils")

-- Load shared annotations/types.
require("venv-selector.types")

local M = {}
M.__index = M

---@type any|nil
local active_telescope_instance = nil

---@param line any
---@return integer rank
---@return string rest
local function split_prefix(line)
    line = tostring(line or "")
    local pfx = line:sub(1, 2)
    if pfx == "0 " then return 0, line:sub(3) end
    if pfx == "1 " then return 1, line:sub(3) end
    return 1, line
end

---@param prompt string
---@param line string
---@return string p
---@return string l
local function smartcase_prepare(prompt, line)
    line = tostring(line or "")
    if prompt:match("%u") then
        return prompt, line
    end
    return prompt:lower(), line:lower()
end

---@return any sorter
local function make_smartcase_substring_sorter()
    local sorters = require("telescope.sorters")
    return sorters.new {
        scoring_function = function(_, prompt, line)
            local rank, raw = split_prefix(line)

            if not prompt or prompt == "" then
                return rank
            end

            local p, l = smartcase_prepare(prompt, raw)
            local start = l:find(p, 1, true)
            if not start then return -1 end

            return (rank * 1000000) + start
        end,
        highlighter = function() return {} end,
    }
end

---@return any sorter
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

---@return table layout_config
local function get_dynamic_layout_config()
    local columns = vim.o.columns

    local width_ratio = 0.9
    local min_width = 60
    local max_width = 120
    local dynamic_width = math.max(min_width, math.min(max_width, math.floor(columns * width_ratio)))

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

---@return table display_config
local function get_dynamic_display_config()
    local columns = vim.o.columns
    local picker_columns = gui_utils.get_picker_columns()

    local reserved_space = 6
    local available_space = columns - reserved_space

    local name_width, source_width
    if columns < 80 then
        name_width = math.floor(available_space * 0.75)
        source_width = math.floor(available_space * 0.25)
    elseif columns < 120 then
        name_width = math.floor(available_space * 0.65)
        source_width = math.floor(available_space * 0.35)
    else
        name_width = math.min(90, math.floor(available_space * 0.6))
        source_width = math.min(30, math.floor(available_space * 0.4))
    end

    name_width = math.max(20, name_width)
    source_width = math.max(8, source_width)

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

    if #items > 0 then
        items[#items].remaining = true
    end

    return {
        separator = " ",
        items = items,
    }
end

function M:update_results()
    local bufnr = vim.api.nvim_get_current_buf()
    local picker = require("telescope.actions.state").get_current_picker(bufnr)
    if picker ~= nil then
        picker.layout_config = get_dynamic_layout_config()
        picker:full_layout_update()
        picker:refresh(self:make_finder(), { reset_prompt = false })
    end
end

---@param result venv-selector.SearchResult
function M:insert_result(result)
    table.insert(self.results, result)

    if self._refresh_scheduled then
        return
    end
    self._refresh_scheduled = true

    vim.defer_fn(function()
        self._refresh_scheduled = false
        self:update_results()
    end, 30)
end

function M:search_done()
    self.results = gui_utils.remove_dups(self.results)
    gui_utils.sort_results(self.results)
    self:update_results()
end

function M:setup_resize_autocmd()
    local group = vim.api.nvim_create_augroup("VenvSelectorTelescope", { clear = true })

    vim.api.nvim_create_autocmd("VimResized", {
        group = group,
        callback = function()
            if active_telescope_instance == self then
                vim.defer_fn(function()
                    if active_telescope_instance == self then
                        self:update_results()
                    end
                end, 50)
            else
                vim.api.nvim_del_augroup_by_id(group)
            end
        end,
    })
end

---@return any finder
function M:make_finder()
    local display_config = get_dynamic_display_config()
    local displayer = require("telescope.pickers.entry_display").create(display_config)

    local entry_maker = function(entry)
        ---@cast entry venv-selector.SearchResult

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

            local hl = gui_utils.hl_active_venv(entry)
            local marker_icon = config.user_settings.options.selected_venv_marker_icon
                or config.user_settings.options.icon
                or "●"

            local marker_hl = hl and "VenvSelectMarker" or nil

            local column_data = {
                marker = { hl and marker_icon or " ", marker_hl },
                search_icon = { gui_utils.draw_icons_for_types(entry.source) },
                search_name = { e.source },
                search_result = { e.name },
            }

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


---@return any sorter
local function get_sorter()
    local filter_type = config.get_user_options().picker_filter_type

    if filter_type == "character" then
        return make_smartcase_subsequence_sorter()
    end
    return make_smartcase_substring_sorter()
end

---@param search_opts table
---@return venv-selector.Picker
function M.new(search_opts)
    ---@type venv-selector.Picker & { results: venv-selector.SearchResult[], _refresh_scheduled?: boolean }
    local self = setmetatable({ results = {} }, M)

    active_telescope_instance = self

    local marker_color = config.user_settings.options.selected_venv_marker_color
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

            map("i", "<Tab>", false)
            map("i", "<S-Tab>", false)
            map("n", "<Tab>", false)
            map("n", "<S-Tab>", false)

            return true
        end,
    }

    local picker = require("telescope.pickers").new({}, opts)

    local augroup = vim.api.nvim_create_augroup("VenvSelectTelescope", { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
        group = augroup,
        callback = function(ev)
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
    self:setup_resize_autocmd()

    return self
end



return M
