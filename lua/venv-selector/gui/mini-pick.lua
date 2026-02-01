local gui_utils = require("venv-selector.gui.utils")
local config = require("venv-selector.config")

local M = {}
M.__index = M

local NS = vim.api.nvim_create_namespace("VenvSelectMiniPick")

local function marker_icon()
    return config.user_settings.options.selected_venv_marker_icon or "✔"
end

local function item_to_text(item)
    local icon = marker_icon()
    local marker = gui_utils.hl_active_venv(item) and icon or " "
    local src_icon = gui_utils.draw_icons_for_types(item.source)
    local src_name = string.format("%-15s", item.source)
    return table.concat({ marker, src_icon, src_name, item.name }, "  ")
end


local function show_with_marker_hl(buf_id, items, query)
    local mini_pick = require("mini.pick")
    mini_pick.default_show(buf_id, items, query)

    vim.api.nvim_buf_clear_namespace(buf_id, NS, 0, -1)

    local icon = marker_icon()
    local icon_bytes = #icon

    -- each rendered line corresponds to items[i]
    for i, item in ipairs(items) do
        if gui_utils.hl_active_venv(item) then
            -- highlight marker at start of line
            vim.api.nvim_buf_add_highlight(buf_id, NS, "VenvSelectMarker", i - 1, 0, icon_bytes)
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
    result.text = item_to_text(result)
    result.path = result.path
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

    mini_pick.start({
        source = {
            name = "Virtual environments",
            items = self.results,
            show = show_with_marker_hl,
            choose = function(item)
                gui_utils.select(item)
            end,
        },
    })
end

return M
