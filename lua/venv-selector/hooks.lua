local lspconfig = require("lspconfig")

local M = {}

--- @alias NvimLspClient table
--- @alias ClientCallback function(client: NvimLspClient): nil
--- @type function(name: string, callback: ClientCallback): nil
local function execute_for_client(name, callback)
	local dbg = require("venv-selector.utils").dbg
	local client = vim.lsp.get_active_clients({ name = name })[1]

	if not client then
		dbg("No client named: " .. name .. " found")
		return
	end

	callback(client)
end

--- @type function(string, string): nil
M.pyright_hook = function(_, venv_python)
	local utils = require("venv-selector.utils")

	execute_for_client("pyright", function(pyright)
		local settings = utils.deep_copy(pyright.config.settings)
		lspconfig.pyright.setup({
			settings = settings,
			before_init = function(_, c)
				c.settings.python.pythonPath = venv_python
			end,
		})
	end)
end

return M
