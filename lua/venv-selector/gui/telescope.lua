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
    local filter_type = config.user_settings.options.picker_filter_type or
    config.user_settings.options.telescope_filter_type

    if filter_type == "character" then
        return require("telescope.config").values.file_sorter()
    elseif filter_type == "substring" then
        return require("telescope.sorters").get_substr_matcher()
    end
end



-- Create empty picker for streaming (doesn't start search automatically)
function M.new_streaming(search_opts)
    local self = setmetatable({ results = {}, telescope_picker = nil }, M)

    -- Set this as the active instance for resize handling
    active_telescope_instance = self

    -- Setup highlight groups for marker color
    local marker_color = config.user_settings.options.selected_venv_marker_color or
    config.user_settings.options.telescope_active_venv_color

    -- Create marker highlight group
    vim.api.nvim_set_hl(0, "VenvSelectMarker", { fg = marker_color })

    return self
end

-- Setup streaming events for this picker instance
function M:setup_streaming_events(search_opts)
    local picker_id = tostring(self)
    local result_event = "search_result_found_" .. picker_id
    local complete_event = "search_complete_" .. picker_id
    local events = require("venv-selector.events")
    
    events.on(result_event, function(args)
        local result = args.data.result
        self:insert_result(result)
    end, { once = false })
    
    events.on(complete_event, function(args)
        self:search_done()
    end, { once = true })
    
    -- Start streaming search
    require("venv-selector.search").run_search_streaming(self, search_opts, {
        result_event = result_event,
        complete_event = complete_event
    })
end

-- Open the telescope picker (called after event listeners are set up)
function M:open_picker(search_opts)
    local opts = {
        prompt_title = "Virtual environments (ctrl-r to refresh)",
        finder = self:make_finder(),
        layout_strategy = "vertical",
        layout_config = get_dynamic_layout_config(),
        cwd = require("telescope.utils").buffer_dir(),

        sorting_strategy = "ascending",
        sorter = get_sorter(),
        selection_strategy = "reset",
        scroll_strategy = "limit",
        multi_selection = false,
        default_selection_index = 1,
        attach_mappings = function(bufnr, map)
            map({ "i", "n" }, "<cr>", function()
                local selected_entry = require("telescope.actions.state").get_selected_entry()
                gui_utils.select(selected_entry)
                require("telescope.actions").close(bufnr)
            end)

            map("i", "<C-r>", function()
                self.results = {}
                -- Clear cache and trigger fresh streaming search
                require("venv-selector.gui").clear_cache()
                self:setup_streaming_events(search_opts)
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

    -- Store reference to telescope picker
    self.telescope_picker = require("telescope.pickers").new({}, opts)
    self.telescope_picker:find()
    
    -- Force selection to first result immediately after opening
    vim.schedule(function()
        if self.telescope_picker and #self.results > 0 then
            pcall(function()
                self.telescope_picker:set_selection(1)
            end)
        end
    end)
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

function M:update_results()
    if self.telescope_picker then
        -- Check if telescope picker is still valid before updating
        local ok = pcall(function()
            -- Update layout configuration for new window size
            self.telescope_picker.layout_config = get_dynamic_layout_config()
            self.telescope_picker:full_layout_update()
            -- Then refresh the finder with new column widths
            self.telescope_picker:refresh(self:make_finder(), { reset_prompt = false })
        end)
        
        if not ok then
            -- Telescope picker is no longer valid, ignore further updates
            self.telescope_picker = nil
        end
    end
end

function M:insert_result(result)
    table.insert(self.results, result)
    
    -- Batch updates to reduce visual jumping - update every 5 results or for first 10
    if #self.results % 5 == 0 or #self.results <= 10 then
        self:update_results()
        
        -- For first result, ensure it's selected
        if #self.results == 1 then
            vim.schedule(function()
                if self.telescope_picker then
                    pcall(function()
                        self.telescope_picker:set_selection(1)
                    end)
                end
            end)
        end
    end
end

function M:search_done()
    -- Final sort and cleanup
    self.results = gui_utils.remove_dups(self.results)
    gui_utils.sort_results(self.results)
    
    -- Force final update to ensure all results are displayed with proper sorting
    self:update_results()
    
    -- Ensure first result is selected after final sort
    self:ensure_selection()
end

function M:ensure_selection()
    if self.telescope_picker and #self.results > 0 then
        vim.schedule(function()
            pcall(function()
                self.telescope_picker:set_selection(1)
            end)
        end)
    end
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
