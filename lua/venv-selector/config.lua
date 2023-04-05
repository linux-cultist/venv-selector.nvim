local system = require("venv-selector.system")
config = {
	settings = {},
}

-- Default settings if user is not setting anything in setup() call
config.default_settings = {
	search = true,
	name = "venv",
	search_workspace = true,
	search_venv_managers = true,
	parents = 2, -- When search is true, go this many directories up from the current opened buffer
	poetry_path = system.get_venv_manager_default_path("Poetry"),
	pipenv_path = system.get_venv_manager_default_path("Pipenv"),
	enable_debug_output = false,
	auto_refresh = true,
}

-- Gets the search path supplied by the user in the setup function, or use current open buffer directory.
config.get_search_path = function()
	local dbg = require("venv-selector.utils").dbg
	local path
	if config.settings.path == nil then
		path = vim.fn.expand("%:p:h")
		dbg("Using path from expand: " .. path)
	else
		path = config.settings.path
		dbg("Using path from settings path: " .. path)
	end
	return path
end

return config
