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
			choose = function(item)
				gui_utils.select(item)
			end,
		}
	})
end

return M
