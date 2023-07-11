local utils = require("venv-selector.utils")
local dbg = require("venv-selector.utils").dbg

local M = {
  results = {},
  finders = require("telescope.finders"),
  conf = require("telescope.config").values,
  pickers = require("telescope.pickers"),
  actions_state = require("telescope.actions.state"),
  actions = require("telescope.actions"),
  entry_display = require("telescope.pickers.entry_display"),
}

M.add_lines = function(lines, source)
  local icon = source == "Workspace" and "" or ""

  for row in lines do
    if row ~= "" then
      dbg("Found venv in " .. source .. " search: " .. row)
      table.insert(M.results, { icon = icon, path = utils.remove_last_slash(row) })
    end
  end
end

M.tablelength = function(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end


-- This function removes duplicate results when loading results into telescope
M.prepare_results = function()
  local hash = {}
  local res = {}

  for _, v in ipairs(M.results) do
    if not hash[v.path] then
      res[#res + 1] = v
      hash[v.path] = true
    end
  end

  M.results = res

  dbg("There are " .. M.tablelength(M.results) .. " results to show:")
end

M.remove_results = function()
  M.results = {}
  dbg("Removed telescope results.")
end

-- Shows the results from the search in a Telescope picker.
M.show_results = function()
  local displayer = M.entry_display.create({
    separator = " ",
    items = {
      { width = 2 },
      { width = 0.95 },
    },
  })


  local title = "Virtual environments"

  if config.settings.auto_refresh == false then
    title = title .. " (ctrl-r to refresh)"
  end

  M.prepare_results();

  local finder = M.finders.new_table({
    results = M.results,
    entry_maker = function(entry)
      entry.value = entry.path
      entry.ordinal = entry.path
      entry.display = function(e)
        return displayer({
          { e.icon },
          { e.path },
        })
      end

      return entry
    end,
  })

  local opts = {
    prompt_title = title,
    finder = finder,
    -- results_title = title,
    layout_strategy = "horizontal",
    layout_config = {
      height = 0.4,
      width = 120,
      prompt_position = "top",
    },
    cwd = require("telescope.utils").buffer_dir(),
    sorting_strategy = "descending",
    sorter = M.conf.file_sorter({}),
    attach_mappings = function(bufnr, map)
      local venv = require("venv-selector.venv")
      map("i", "<CR>", function()
        local actions = require("telescope.actions")
        -- actions.drop_all(bufnr)
        -- actions.add_selection(bufnr)
        venv.activate_venv()
        actions.close(bufnr)
        -- M.mypicker:refresh()
      end)
      map("i", "<C-r>", function()
        venv.reload({ force_refresh = true })
      end)
      return true
    end,
  }
  -- utils.print_table(opts)
  M.pickers.new({}, opts):find()
end

-- Gets called on results from the async search and adds the findings
-- to telescope.results to show when its done.
M.on_read = function(err, data)
  if err then
    print("Error:" .. err)
  end

  if data then
    local rows = vim.split(data, "\n")
    for _, row in pairs(rows) do
      if row ~= "" then
        dbg("Found venv in parent search: " .. row)
        table.insert(M.results, { icon = "󰅬", path = utils.remove_last_slash(row), source = "Search" })
      end
    end
  end
end

return M
