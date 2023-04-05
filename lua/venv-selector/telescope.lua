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

M.add_lines = function(lines)
	for line in lines do
		if line ~= "" then
			dbg("Adding row to telescope results: " .. line)
			table.insert(M.results, utils.remove_last_slash(line))
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
			{ width = 10 },
			{ width = 10 },
			{ width = 10 },
		},
	})
	local make_display = function(entry)
		return displayer({
			{ entry.name },
			{ entry.color },
			{ entry.gender },
		})
	end

	local venv = require("venv-selector.venv")
	local opts = {
		prompt_title = "Python virtual environments",
		finder = M.finders.new_table({
			-- results = utils.remove_duplicates_from_table(M.results),
			results = {
				{ name = "", color = "#ff0000", gender = "male" },
				{ name = "", color = "#0000ff", gender = "female" },
			},
			entry_maker = function(entry)
				entry.value = entry.name
				entry.ordinal = entry.name
				entry.display = make_display
				return entry
			end,
		}),
		layout_strategy = "vertical",
		layout_config = {
			height = 20,
			width = 100,
			prompt_position = "top",
		},
		sorting_strategy = "descending",
		sorter = M.conf.file_sorter({}),
		attach_mappings = function(bufnr, map)
			map("i", "<CR>", venv.activate_venv)
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
				table.insert(M.results, utils.remove_last_slash(row))
			end
		end
	end
end

return M
