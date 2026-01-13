local gui_utils = require("venv-selector.gui.utils")

local M = {}
M.__index = M

local function get_dynamic_winopts()
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
        row = 0.5,
    }
end

function M.new(search_opts)
    local self = setmetatable({ is_done = false, queue = {}, entries = {}, is_closed = false, picker_started = false }, M)

    local config = require("venv-selector.config")
    local filter_type = config.user_settings.options.picker_filter_type or
        config.user_settings.options.telescope_filter_type or "substring"
    local algo = filter_type == "substring" and "v2" or "v1"

    local fzf_lua = require("fzf-lua")
    
    -- Set up autocmd to detect when fzf-lua window closes
    local augroup = vim.api.nvim_create_augroup("VenvSelectFzfLua", { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
        group = augroup,
        callback = function(ev)
            -- Check if this is an fzf-lua window by checking buffer name
            local winid = tonumber(ev.match)
            if winid then
                local ok, bufnr = pcall(vim.api.nvim_win_get_buf, winid)
                if ok then
                    local bufname = vim.api.nvim_buf_get_name(bufnr)
                    -- fzf-lua buffers typically have 'fzf' in their name
                    if bufname:match("fzf") or vim.bo[bufnr].filetype == "fzf" then
                        -- Mark picker as closed and stop any active search jobs
                        self.is_closed = true
                        self.fzf_cb = nil  -- Clear callback to prevent reopening
                        require("venv-selector.search").stop_search()
                        vim.api.nvim_del_augroup_by_id(augroup)
                    end
                end
            end
        end,
    })
    
    fzf_lua.fzf_exec(function(fzf_cb)
        self.fzf_cb = fzf_cb
        self:consume_queue()
    end, {
        prompt = "Virtual environments > ",
        winopts = vim.tbl_extend("force", get_dynamic_winopts(), {
            on_create = function()
                vim.cmd("startinsert")
            end,
        }),
        fzf_opts = {
            ["--tabstop"] = "1",
            ["--algo"] = algo,
            ["--exact"] = filter_type == "substring",
            ["--literal"] = filter_type == "substring",
            ["--no-multi"] = true,
        },
        actions = {
            ["default"] = function(selected, _)
                if selected and #selected > 0 then
                    local selected_entry = self.entries[selected[1]]
                    gui_utils.select(selected_entry)
                end
            end,
        },
    })

    return self
end

function M:consume_queue()
    -- Don't process results if picker was closed or fzf_cb was cleared
    if self.is_closed or not self.fzf_cb then
        return
    end
    
    if self.fzf_cb then
        for _, result in ipairs(self.queue) do
            local fzf = require("fzf-lua")

            local hl = gui_utils.hl_active_venv(result)

            -- Format entry with configurable column order
            local config = require("venv-selector.config")
            -- Prepare column data
            local type_icon = gui_utils.draw_icons_for_types(result.source)
            local marker
            if hl then
                local color = config.user_settings.options.selected_venv_marker_color or
                    config.user_settings.options.telescope_active_venv_color
                local icon = config.user_settings.options.selected_venv_marker_icon or config.user_settings.options.icon or
                    "●"
                -- Convert hex color to ANSI escape sequence
                local r = tonumber(color:sub(2, 3), 16)
                local g = tonumber(color:sub(4, 5), 16)
                local b = tonumber(color:sub(6, 7), 16)
                marker = string.format("\27[38;2;%d;%d;%dm%s \27[0m", r, g, b, icon)
            else
                marker = "  "
            end

            local column_data = {
                marker = marker,
                search_icon = type_icon,
                search_name = string.format("%-15s", result.source),
                search_result = result.name
            }

            -- Build entry based on configured column order
            local columns = gui_utils.get_picker_columns()
            local parts = {}
            for _, col in ipairs(columns) do
                if column_data[col] then
                    table.insert(parts, column_data[col])
                end
            end
            entry = table.concat(parts, "  ")

            -- No need to strip ansi colors since we're not using them anymore
            self.entries[entry] = result
            self.fzf_cb(entry)
        end
        self.queue = {}

        -- notify to fzf-lua that we are done generating results
        if self.is_done then
            self.fzf_cb(nil)
        end
    end
end

function M:insert_result(result)
    -- Don't accept new results if picker was closed
    if self.is_closed then
        return
    end
    
    -- Just queue results, don't consume until search is done
    self.queue[#self.queue + 1] = result
end

function M:search_done()
    -- Don't do anything if picker was already closed
    if self.is_closed then
        return
    end

    -- Process all queued results
    self.is_done = true
    self:consume_queue()
end

return M
