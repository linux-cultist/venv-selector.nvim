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

    self._flush_scheduled = false
    self._flush_ms = 15
    self._batch_size = 25

    local config = require("venv-selector.config")
    local filter_type = config.user_settings.options.picker_filter_type
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
                        self.fzf_cb = nil -- Clear callback to prevent reopening
                        require("venv-selector.search").stop_search()
                        vim.api.nvim_del_augroup_by_id(augroup)
                    end
                end
            end
        end,
    })

    fzf_lua.fzf_exec(function(fzf_cb)
        self.fzf_cb = fzf_cb
        -- do NOT call consume_queue() here; wait for streaming inserts
    end, {
        prompt = "Virtual environments > ",
        winopts = vim.tbl_extend("force", get_dynamic_winopts(), {
            on_create = function() vim.cmd("startinsert") end,
        }),
        fzf_opts = {
            ["--tabstop"] = "1",
            ["--algo"] = algo,
            ["--smart-case"] = true,
            ["--ansi"] = true,
            ["--no-sort"] = true, -- required to preserve emission order
            ["--no-multi"] = true,
            ["--exact"] = (filter_type == "substring") and true or nil,
            ["--literal"] = (filter_type == "substring") and true or nil,
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

local function schedule_flush(self)
    if self._flush_scheduled or not self.fzf_cb or self.is_closed then
        return
    end
    self._flush_scheduled = true

    vim.defer_fn(function()
        self._flush_scheduled = false
        if self.is_closed or not self.fzf_cb then
            return
        end
        self:consume_queue()
    end, self._flush_ms or 25)
end



function M:consume_queue()
    if self.is_closed or not self.fzf_cb then
        return
    end

    if #self.queue == 0 then
        if self.is_done then
            self.fzf_cb(nil)
        end
        return
    end

    -- Dedup (keep active if duplicates) and keep queue stable
    self.queue = gui_utils.remove_dups(self.queue)

    -- Gate until we have an active item (unless done)
    if not self.is_done then
        local has_active = false
        for _, r in ipairs(self.queue) do
            if gui_utils.hl_active_venv(r) ~= nil then
                has_active = true
                break
            end
        end
        if not has_active then
            return
        end
    end

    -- Partition: active first, then rest (rest sorted)
    local active, rest = {}, {}
    for _, r in ipairs(self.queue) do
        if gui_utils.hl_active_venv(r) ~= nil then
            active[#active + 1] = r
        else
            rest[#rest + 1] = r
        end
    end
    gui_utils.sort_results(rest)

    local emit = vim.list_extend(active, rest)

    local cfg = require("venv-selector.config")
    local columns = gui_utils.get_picker_columns()
    local batch_size = self._batch_size or 50

    -- Emit only a batch
    local emitted = 0
    local remaining = {}

    for i, result in ipairs(emit) do
        if emitted < batch_size then
            local hl = gui_utils.hl_active_venv(result)
            local type_icon = gui_utils.draw_icons_for_types(result.source)

            local marker
            if hl then
                local color = cfg.user_settings.options.selected_venv_marker_color
                    or cfg.user_settings.options.telescope_active_venv_color
                local icon = cfg.user_settings.options.selected_venv_marker_icon
                    or cfg.user_settings.options.icon
                    or "●"
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
                search_result = result.name,
            }

            local parts = {}
            for _, col in ipairs(columns) do
                if column_data[col] then
                    parts[#parts + 1] = column_data[col]
                end
            end

            local entry = table.concat(parts, "  ")
            self.entries[entry] = result
            self.fzf_cb(entry)
            emitted = emitted + 1
        else
            remaining[#remaining + 1] = result
        end
    end

    -- Keep remaining queued for next flush
    self.queue = remaining

    -- If done and nothing left, close the stream
    if self.is_done and #self.queue == 0 then
        self.fzf_cb(nil)
        return
    end

    -- If there is more, schedule next flush
    if #self.queue > 0 then
        vim.defer_fn(function()
            if not self.is_closed and self.fzf_cb then
                self:consume_queue()
            end
        end, self._flush_ms or 25)
    end
end

function M:insert_result(result)
    if self.is_closed then
        return
    end

    self.queue[#self.queue + 1] = result
    schedule_flush(self)
end

function M:search_done()
    if self.is_closed then
        return
    end
    self.is_done = true
    if self.fzf_cb then
        self:consume_queue()
    end
end

return M
