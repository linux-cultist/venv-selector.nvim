local utils = {}

utils.system = vim.loop.os_uname().sysname

utils.venv_manager_default_paths = {
	Poetry = {
		Linux = "~/.cache/pypoetry/virtualenvs",
		Darwin = "~/Library/Caches/pypoetry/virtualenvs",
		Windows_NT = "%APPDATA%\\pypoetry\\virtualenvs",
	},
	Pipenv = {
		Linux = "~/.local/share/virtualenvs",
		Darwin = "~/.local/share/virtualenvs",
		Windows_NT = "~\\virtualenvs",
	},
}

utils.print_table = function(t)
	print(vim.inspect(t))
end

utils.escape_pattern = function(text)
	return text:gsub("([^%w])", "%%%1")
end

utils.get_python_parent_path = function()
	if utils.system == "Linux" or utils.system == "Darwin" then
		return "bin"
	else
		return "Scripts"
	end
end

utils.get_python_name = function()
	if utils.system == "Linux" or utils.system == "Darwin" then
		return "python"
	else
		return "python.exe"
	end
end

-- Creating a regex search path string with all venv names separated by
-- the '|' character. We also make sure that the venv name is an exact match
-- using '^' and '$' so we dont match on paths with the venv name in the middle.
utils.create_fd_venv_names_regexp = function(config_venv_name)
	local venv_names = ""

	if type(config_venv_name) == "table" then
		venv_names = venv_names .. "("
		for _, venv_name in pairs(config_venv_name) do
			venv_names = venv_names .. "^" .. venv_name .. "$" .. "|" -- Creates (^venv_name1$ | ^venv_name2$ ) etc
		end
		venv_names = venv_names:sub(1, -2) -- Always remove last '|' since we only want it between words
		venv_names = venv_names .. ")"
	else
		if type(config_venv_name) == "string" then
			venv_names = "^" .. config_venv_name .. "$"
		end
	end

	return venv_names
end

-- Create a search path string to fd command with all paths instead of
-- running fd several times.
utils.create_fd_search_path_string = function(paths)
	local search_path_string = ""
	for _, path in pairs(paths) do
		local expanded_path = vim.fn.expand(path)
		if vim.fn.isdirectory(expanded_path) ~= 0 then
			search_path_string = search_path_string .. "--search-path " .. expanded_path .. " "
		end
	end
	return search_path_string
end

utils.get_system_differences = function()
	local result = {
		system = utils.system,
		path_sep = utils.get_system_path_separator(),
		python_name = utils.get_python_name(),
		python_parent_path = utils.get_python_parent_path(),
	}
	return result
end

utils.get_system_path_separator = function()
	if utils.system == "Linux" or utils.system == "Darwin" then
		return "/"
	else
		return "\\"
	end
end

utils.get_venv_manager_default_path = function(venv_manager_name)
	return utils.venv_manager_default_paths[venv_manager_name][utils.system]
end

utils.remove_last_slash = function(s)
	local separator = utils.get_system_path_separator()

	if string.sub(s, -1, -1) == separator then
		return string.sub(s, 1, -2)
	end
end

return utils
