local utils = require("venv-selector.utils")
local dbg = require("venv-selector.utils").dbg
local M = {
	results = {},
	finders = require("telescope.finders"),
	conf = require("telescope.config").values,
	pickers = require("telescope.pickers"),
	actions_state = require("telescope.actions.state"),
	actions = require("telescope.actions"),
}

M.add_lines = function(lines)
	for line in lines do
		if line ~= "" then
			table.insert(M.results, utils.remove_last_slash(line))
		end
	end
end

-- Shows the results from the search in a Telescope picker.
M.show_results = function()
	local venv = require("venv-selector.venv")
	local opts = {
		layout_strategy = "vertical",
		layout_config = {
			height = 20,
			width = 100,
			prompt_position = "top",
		},
		sorting_strategy = "descending",
		prompt_title = "Python virtual environments",
		finder = M.finders.new_table(utils.remove_duplicates_from_table(M.results)),
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
