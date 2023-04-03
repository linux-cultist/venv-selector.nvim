local system = require("venv-selector.system")
config = {}

config.settings = {}

-- Default settings if user is not setting anything in setup() call
config.default_settings = {
	search = true,
	name = "venv",
	parents = 2, -- When search is true, go this many directories up from the current opened buffer
	poetry_path = system.get_venv_manager_default_path("Poetry"),
	pipenv_path = system.get_venv_manager_default_path("Pipenv"),
}

-- Gets the search path supplied by the user in the setup function, or use current open buffer directory.
config.get_search_path = function()
	if config.settings.path == nil then
		return vim.fn.expand("%:p:h")
	end

	return config.settings.path
end

return config
