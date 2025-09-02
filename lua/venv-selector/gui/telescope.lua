local config = require("venv-selector.config")
local gui_utils = require("venv-selector.gui.utils")

local M = {}
M.__index = M

-- Track active telescope instance for auto-refresh on resize
local active_telescope_instance = nil

local function get_dynamic_layout_config()
    local columns = vim.o.columns
    local lines = vim.o.lines

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

local function get_sorter()
    local filter_type = config.user_settings.options.picker_filter_type or config.user_settings.options.telescope_filter_type

    if filter_type == "character" then
        return require("telescope.config").values.file_sorter()
    elseif filter_type == "substring" then
        return require("telescope.sorters").get_substr_matcher()
    end
end

function M.new(search_opts)
    local self = setmetatable({ results = {} }, M)

    -- Set this as the active instance for resize handling
    active_telescope_instance = self
    
    -- Setup highlight groups for marker color
    local marker_color = config.user_settings.options.selected_venv_marker_color or config.user_settings.options.telescope_active_venv_color
    
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
        on_close = function()
            -- Clear active instance when telescope closes
            active_telescope_instance = nil
        end,
    }

    -- Set up autocmd for window resize
    self:setup_resize_autocmd()

    require("telescope.pickers").new({}, opts):find()

    return self
end

function M:make_finder()
    local display_config = get_dynamic_display_config()
    local displayer = require("telescope.pickers.entry_display").create(display_config)

    local entry_maker = function(entry)
        local icon = entry.icon
        entry.value = entry.name
        entry.ordinal = entry.path
        entry.display = function(e)
            local picker_columns = gui_utils.get_picker_columns()
            
            -- Prepare column data
            local hl = gui_utils.hl_active_venv(entry)
            local marker_icon = config.user_settings.options.selected_venv_marker_icon or config.user_settings.options.icon or "●"
            
            -- Use pre-created highlight groups
            local marker_hl = hl and "VenvSelectMarker" or nil
            
            local column_data = {
                marker = {
                    hl and marker_icon or " ",
                    marker_hl,
                },
                search_icon = {
                    config.user_settings.options.show_telescope_search_type and gui_utils.draw_icons_for_types(
                        entry.source
                    ) or "",
                },
                search_name = {
                    config.user_settings.options.show_telescope_search_type and e.source or "",
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

function M:insert_result(result)
    table.insert(self.results, result)
    self:update_results()
end

function M:search_done()
    self.results = gui_utils.remove_dups(self.results)
    gui_utils.sort_results(self.results)

    self:update_results()
end

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
