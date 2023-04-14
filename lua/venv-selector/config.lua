local system = require("venv-selector.system")
local user = vim.fn.getenv("USER")
local config = {
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
	auto_refresh = false, -- Uses cached results from last search
	fd_binary_name = "fd",
	cache_file = "/home/" .. user .. "/.cache/venv-selector/venvs.json",
	cache_dir = "/home/" .. user .. "/.cache/venv-selector",
	dap_enabled = false,
}

-- Gets the search path supplied by the user in the setup function, or use current open buffer directory.
config.get_buffer_dir = function()
	local dbg = require("venv-selector.utils").dbg
	local path
	if config.settings.path == nil then
		path = require("telescope.utils").buffer_dir()
		dbg("Telescope path: " .. path)
		-- path = vim.fn.expand("%:p:h")
		-- dbg("Using path from vim.fn.expand: " .. path)
	else
		path = config.settings.path
		dbg("Using path from settings path: " .. path)
	end
	return path
end

return config
