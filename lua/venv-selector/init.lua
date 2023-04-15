local venv = require("venv-selector.venv")
local config = require("venv-selector.config")
local user_commands = require("venv-selector.user_commands")
local dbg = require("venv-selector.utils").dbg
local hooks = require("venv-selector.hooks")

M = {
	-- Called by user when using the plugin.
	setup = function(settings)
		-- Let user config overwrite any default config options.
		config.settings = vim.tbl_deep_extend("force", config.default_settings, settings or {})
		dbg(config.settings)

		-- Create the VenvSelect command.
		user_commands.setup_user_commands("VenvSelect", M.reload, "Use VenvSelect to activate a venv")
	end,
	-- Gets the system path to current active python in the venv (or nil if its not activated)
	get_active_path = function()
		return venv.current_python_path
	end,
	-- Gets the system path to the current active venv (or nil if its not activated)
	get_active_venv = function()
		return venv.current_venv
	end,
	-- The main function runs when user executes VenvSelect command
	reload = function()
		venv.reload()
	end,
	hooks = {
		pyright = hooks.pyright_hook,
		pylsp = hooks.pylsp_hook,
	},
}

return M
-- VS.setup()
