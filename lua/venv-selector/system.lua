local system = {}

system.sysname = vim.loop.os_uname().sysname

system.venv_manager_default_paths = {
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

system.get_venv_manager_default_path = function(venv_manager_name)
	return system.venv_manager_default_paths[venv_manager_name][system.sysname]
end

system.get_python_parent_path = function()
	if system.sysname == "Linux" or system.sysname == "Darwin" then
		return "bin"
	else
		return "Scripts"
	end
end

system.get_python_name = function()
	if system.sysname == "Linux" or system.sysname == "Darwin" then
		return "python"
	else
		return "python.exe"
	end
end

system.get_path_separator = function()
	if system.sysname == "Linux" or system.sysname == "Darwin" then
		return "/"
	else
		return "\\"
	end
end

system.get_info = function()
	return {
		sysname = vim.loop.os_uname().sysname,
		path_sep = system.get_path_separator(),
		python_name = system.get_python_name(),
		python_parent_path = system.get_python_parent_path(),
	}
end

return system
