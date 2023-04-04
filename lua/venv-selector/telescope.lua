local telescope = {}
local venv = require("venv-selector.venv")
local utils = require("venv-selector.utils")

telescope.results = {}

telescope.finders = require("telescope.finders")
telescope.conf = require("telescope.config").values
telescope.pickers = require("telescope.pickers")
telescope.actions_state = require("telescope.actions.state")
telescope.actions = require("telescope.actions")

telescope.add_lines = function(lines)
	for line in lines do
		if line ~= "" then
			table.insert(telescope.results, utils.remove_last_slash(line))
		end
	end
end

-- Shows the results from the search in a Telescope picker.
telescope.show_results = function()
	local opts = {
		layout_strategy = "vertical",
		layout_config = {
			height = 20,
			width = 100,
			prompt_position = "top",
		},
		sorting_strategy = "descending",
		prompt_title = "Python virtual environments",
		finder = telescope.finders.new_table(utils.remove_duplicates_from_table(telescope.results)),
		sorter = telescope.conf.file_sorter({}),
		attach_mappings = function(bufnr, map)
			map("i", "<CR>", venv.activate_venv)
			return true
		end,
	}

	telescope.pickers.new({}, opts):find()
end

-- Gets called on results from the async search and adds the findings
-- to telescope.results to show when its done.
telescope.on_read = function(err, data)
	if err then
		print("Error:" .. err)
	end

	if data then
		local rows = vim.split(data, "\n")
		for _, row in pairs(rows) do
			if row ~= "" then
				table.insert(telescope.results, utils.remove_last_slash(row))
			end
		end
	end
end

return telescope
