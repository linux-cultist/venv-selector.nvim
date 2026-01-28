local gui_utils = require("venv-selector.gui.utils")
local config = require("venv-selector.config")

local M = {}
M.__index = M

local H = {}
H.ns_id = vim.api.nvim_create_namespace("MiniPickVenvSelect")

local function marker_icon()
  return config.user_settings.options.selected_venv_marker_icon
    or config.user_settings.options.icon
    or "✔"
end

function M.new()
  local self = setmetatable({ results = {}, picker_started = false }, M)

  local marker_color = config.user_settings.options.selected_venv_marker_color
    or config.user_settings.options.telescope_active_venv_color
  vim.api.nvim_set_hl(0, "VenvSelectMarker", { fg = marker_color })

  return self
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
    if v then parts[#parts + 1] = v end
  end
  return table.concat(parts, "  ")
end

local function apply_marker_hl(buf_id, items_arr)
  pcall(vim.api.nvim_buf_clear_namespace, buf_id, H.ns_id, 0, -1)

  local columns = gui_utils.get_picker_columns()
  local icon = marker_icon()
  local icon_w = vim.fn.strwidth(icon)

  for i, item in ipairs(items_arr) do
    if gui_utils.hl_active_venv(item) then
      local column_data = {
        marker = icon,
        search_icon = gui_utils.draw_icons_for_types(item.source),
        search_name = string.format("%-15s", item.source),
        search_result = item.name,
      }

      local marker_col = 0
      for _, col in ipairs(columns) do
        if col == "marker" then break end
        if column_data[col] then
          marker_col = marker_col + vim.fn.strwidth(column_data[col]) + 2
        end
      end

      pcall(vim.api.nvim_buf_set_extmark, buf_id, H.ns_id, i - 1, marker_col, {
        end_col = marker_col + icon_w,
        hl_group = "VenvSelectMarker",
      })
    end
  end
end

-- Force picker to reflect reorder/dedup by always passing a new table reference.
local function push_items_to_picker(results)
  local mini_pick = require("mini.pick")
  if not mini_pick.is_picker_active() then return end

  local new_items = {}
  for i = 1, #results do
    new_items[i] = results[i]
  end

  mini_pick.set_picker_items(new_items)

  if type(mini_pick.refresh) == "function" then
    mini_pick.refresh()
  else
    vim.cmd("redraw")
  end
end

function M:insert_result(result)
  result.text = result.text or item_to_text(result)
  table.insert(self.results, result)

  local mini_pick = require("mini.pick")

  if not self.picker_started then
    self.picker_started = true
    self:start_picker()
    return
  end

  if mini_pick.is_picker_active() then
    -- Live dedup/sort while streaming (enable if you want immediate changes)
    self.results = gui_utils.remove_dups(self.results)
    gui_utils.sort_results(self.results)

    push_items_to_picker(self.results)
  end
end

function M:search_done()
  self.results = gui_utils.remove_dups(self.results)
  gui_utils.sort_results(self.results)

  push_items_to_picker(self.results)

  if not self.picker_started then
    self.picker_started = true
    self:start_picker()
  end
end

function M:start_picker()
  local mini_pick = require("mini.pick")

  mini_pick.start({
    source = {
      name = "Virtual environments",
      items = self.results,

      match = mini_pick.default_match,

      show = function(buf_id, items_arr, query)
        mini_pick.default_show(buf_id, items_arr, query)
        apply_marker_hl(buf_id, items_arr)
      end,

      choose = function(item)
        gui_utils.select(item)
      end,
    },
  })
end

return M
