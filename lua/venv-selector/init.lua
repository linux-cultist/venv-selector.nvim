local utils = require("venv-selector.utils")
local venv = require("venv-selector.venv")
local telescope = require("venv-selector.telescope")
local config = require("venv-selector.config")

VS = {}

-- The main function runs when user executes VenvSelect command
VS.main = function()
	-- Start with getting venv manager venvs if they exist (Poetry, Pipenv)
	telescope.results = venv.find_venv_manager_venvs()

	-- Only search for other venvs if search option is true
	if config.settings.search == true then
		local path_to_search = config.get_search_path()
		local start_dir = utils.find_parent_dir(path_to_search, config.settings.parents)
		venv.find_venvs(start_dir) -- The results will show up when search is done - dont call telescope.show_results() here.
		return
	end

	telescope.show_results()
end

-- Connect user command to main function
VS.setup_user_command = function()
	vim.api.nvim_create_user_command("VenvSelect", VS.main, { desc = "Use VenvSelect to activate a venv" })
end

-- Called by user when using the plugin.
VS.setup = function(settings)
	-- If no config sent in by user, use empty lua table and later extend it with default options.
	if settings == nil then
		settings = {}
	end

	-- Let user config overwrite any default config options.
	config.settings = vim.tbl_deep_extend("force", config.default_settings, settings)
	utils.print_table(config.settings)

	-- Create the VenvSelect command.
	VS.setup_user_command()
end

return VS
-- VS.setup()
