local utils = require 'venv-selector.utils'
local dbg = require('venv-selector.utils').dbg
local config = require 'venv-selector.config'

local M = {}

M.results = {}

function M.add_lines(lines, source)
  local icon = source == 'Workspace' and '' or ''

  for row in lines do
    if row ~= '' then
      dbg('Found venv in ' .. source .. ' search: ' .. row)
      table.insert(M.results, { icon = icon, path = utils.remove_last_slash(row) })
    end
  end
end

function M.tablelength(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

-- This function removes duplicate results when loading results into telescope
function M.prepare_results()
  local hash = {}
  local res = {}

  for _, v in ipairs(M.results) do
    if not hash[v.path] then
      res[#res + 1] = v
      hash[v.path] = true
    end
  end

  M.results = res

  dbg('There are ' .. M.tablelength(M.results) .. ' results to show.')
end

function M.remove_results()
  M.results = {}
  dbg 'Removed telescope results.'
end

-- Shows the results from the search in a Telescope picker.
function M.show_results()
  local finders = require 'telescope.finders'
  local actions_state = require 'telescope.actions.state'
  local entry_display = require 'telescope.pickers.entry_display'

  M.prepare_results()
  local displayer = entry_display.create {
    separator = ' ',
    items = {
      { width = 2 },
      { width = 0.95 },
    },
  }
  local finder = finders.new_table {
    results = M.results,
    entry_maker = function(entry)
      entry.value = entry.path
      entry.ordinal = entry.path
      entry.display = function(e)
        return displayer {
          { e.icon },
          { e.path },
        }
      end

      return entry
    end,
  }
  local bufnr = vim.api.nvim_get_current_buf()
  local picker = actions_state.get_current_picker(bufnr)
  if picker ~= nil then
    picker:refresh(finder, { reset_prompt = true })
  end
end

-- Gets called on results from the async search and adds the findings
-- to telescope.results to show when its done.
function M.on_read(err, data)
  if err then
    dbg('Error:' .. err)
  end

  if data then
    local rows = vim.split(data, '\n')
    for _, row in pairs(rows) do
      if row ~= '' then
        dbg('Found venv in parent search: ' .. row)
        table.insert(M.results, { icon = '󰅬', path = utils.remove_last_slash(row), source = 'Search' })
      end
    end
  end
end

function M.open()
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local pickers = require 'telescope.pickers'
  local actions_state = require 'telescope.actions.state'
  local actions = require 'telescope.actions'
  local entry_display = require 'telescope.pickers.entry_display'

  local dont_refresh_telescope = config.settings.auto_refresh == false
  local has_telescope_results = next(M.results) ~= nil

  local displayer = entry_display.create {
    separator = ' ',
    items = {
      { width = 2 },
      { width = 0.95 },
    },
  }

  local title = 'Virtual environments'

  if config.settings.auto_refresh == false then
    title = title .. ' (ctrl-r to refresh)'
  end

  local finder = finders.new_table {
    results = M.results,
    entry_maker = function(entry)
      entry.value = entry.path
      entry.ordinal = entry.path
      entry.display = function(e)
        return displayer {
          { e.icon },
          { e.path },
        }
      end

      return entry
    end,
  }

  local venv = require 'venv-selector.venv'
  local opts = {
    prompt_title = title,
    finder = finder,
    -- results_title = title,
    layout_strategy = 'horizontal',
    layout_config = {
      height = 0.4,
      width = 120,
      prompt_position = 'top',
    },
    cwd = require('telescope.utils').buffer_dir(),
    sorting_strategy = 'ascending',
    sorter = conf.file_sorter {},
    attach_mappings = function(bufnr, map)
      map('i', '<cr>', function()
        venv.activate_venv()
        actions.close(bufnr)
      end)

      map('i', '<C-r>', function()
        M.remove_results()
        local picker = actions_state.get_current_picker(bufnr)
        -- Delay by 10ms to achieve the refresh animation.
        picker:refresh(finder, { reset_prompt = true })
        vim.defer_fn(function()
          venv.load { force_refresh = true }
        end, 10)
      end)

      return true
    end,
  }
  pickers.new({}, opts):find()

  if dont_refresh_telescope and has_telescope_results then
    dbg 'Using cached results.'
    return
  end

  venv.load()
  -- venv.load must be called after the picker is displayed; otherwise, Vim will not be able to get the correct bufnr.
end

return M
