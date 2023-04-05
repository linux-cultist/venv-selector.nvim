local M = {
	sysname = vim.loop.os_uname().sysname,
	venv_manager_default_paths = {
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
	},
}

M.get_venv_manager_default_path = function(venv_manager_name)
	return M.venv_manager_default_paths[venv_manager_name][M.sysname]
end

M.get_python_parent_path = function()
	if M.sysname == "Linux" or M.sysname == "Darwin" then
		return "bin"
	else
		return "Scripts"
	end
end

M.get_python_name = function()
	if M.sysname == "Linux" or M.sysname == "Darwin" then
		return "python"
	else
		return "python.exe"
	end
end

M.get_path_separator = function()
	if M.sysname == "Linux" or M.sysname == "Darwin" then
		return "/"
	else
		return "\\"
	end
end

M.get_info = function()
	return {
		sysname = vim.loop.os_uname().sysname,
		path_sep = M.get_path_separator(),
		python_name = M.get_python_name(),
		python_parent_path = M.get_python_parent_path(),
	}
end

return M
