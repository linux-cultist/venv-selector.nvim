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
			show = function(buf_id, items_arr, query)
				local lines = {}
				local highlights = {}

				for index, item in ipairs(items_arr) do
					local hl = gui_utils.hl_active_venv(item)
					highlights.insert(hl)
					lines.insert(gui_utils.format_result_as_string(item.icon, item.source, item.name))
				end

				vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
				for _, hl in ipairs(highlights) do
					if hl then
						vim.api.nvim_buf_add_highlight(buf_id, 0, hl, 0, 0, -1)
					end
				end
			end,
			choose = function(item)
				gui_utils.select(item)
			end,
		}
	})
end

return M
