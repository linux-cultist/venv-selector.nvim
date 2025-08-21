local gui_utils = require("venv-selector.gui.utils")

local M = {}
M.__index = M

function M.new()
	local self = setmetatable({ results = {} }, M)

	return self
end

function M:insert_result(result)
	table.insert(self.results, result)
end

function M:search_done()
	local mini_pick = require("mini.pick")
	self.results = gui_utils.remove_dups(self.results)
	gui_utils.sort_results(self.results)

	-- TODO: is there any way to add color to the results?
	mini_pick.start({
		source = {
			name = "Virtual environments",
			items = self.results,
			preview = function(index)
				local item = self.results[index]
				local lines = {
					"Source: " .. item.source,
					"Name: " .. item.name,
				}
				local pyenv_file = vim.fs.joinpath(item.path, "pyvenv.cfg")
				if vim.fn.filereadable(pyenv_file) == 1 then
					local content = vim.fn.readfile(pyenv_file)
					for _, line in ipairs(content) do
						table.insert(lines, line)
					end
				end
				vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
			end,
			show = function(buf_id, items_arr, query)
				local lines = {}
				for _, item in ipairs(items_arr) do
					table.insert(lines, gui_utils.format_result_as_string(item.icon, item.source, item.name))
				end
				vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
			end,
			choose = function(item)
				gui_utils.select(item)
			end,
		}
	})
end

return M
