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

M.remove_results = function()
  local telescope = require("venv-selector.telescope")
  telescope.results = {}
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
  local make_display = function(entry)
    return displayer({
      { entry.icon },
      { entry.path },
    })
  end
  local title = "Virtual environments"
  if config.settings.auto_refresh == false then
    title = title .. " (ctrl-r to refresh)"
  end
  local venv = require("venv-selector.venv")
  local opts = {
    prompt_title = title,
    -- results_title = title,
    finder = M.finders.new_table({
      results = venv.prepare_results(M.results),
      entry_maker = function(entry)
        entry.value = entry.path
        entry.ordinal = entry.path
        entry.display = make_display
        return entry
      end,
    }),
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
