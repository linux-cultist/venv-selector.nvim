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

--- Returns a table of files and directories in specified directory.
--- Doesn't recurse so only immediate children will be returned.
--- @type fun(dirname: string): string[]
M.list_directory = function(dirname)
	local results = {}

	local list_cmd
	if M.sysname == "Linux" or M.sysname == "Darwin" then
		list_cmd = "ls -1"
	else
		list_cmd = "dir /B"
	end

	for filename in io.popen(list_cmd .. " " .. dirname):lines() do
		table.insert(results, filename)
	end

	return results
end

return M
