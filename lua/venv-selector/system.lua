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
		Pyenv = {
			Linux = "~/.pyenv/versions",
			Darwin = "~/.pyenv/versions",
			Windows = "%USERPROFILE%\\.pyenv\\versions",
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

M.get_cache_default_path = function()
	if M.sysname == "Windows_NT" then
		return vim.fn.getenv("APPDATA") .. "\\venv-selector\\"
	end
	local user = vim.fn.getenv("USER")
	if M.sysname == "Darwin" then
		return "/Users/" .. user .. "/.cache/venv-selector/"
	end
	return "/home/" .. user .. "/.cache/venv-selector/"
end

M.get_info = function()
	--- @class SystemInfo
	--- @field sysname string System namme
	--- @field path_sep string Path separator appropriate for user system
	--- @field python_name string Name of Python binary
	--- @field python_parent_path string Directory containing Python binary on user system
	return {
		sysname = vim.loop.os_uname().sysname,
		path_sep = M.get_path_separator(),
		python_name = M.get_python_name(),
		python_parent_path = M.get_python_parent_path(),
	}
end

return M
