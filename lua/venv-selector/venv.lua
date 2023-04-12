local system = require("venv-selector.system")
local utils = require("venv-selector.utils")
local dbg = require("venv-selector.utils").dbg
local lspconfig = require("lspconfig")
local telescope = require("venv-selector.telescope")
local config = require("venv-selector.config")

local M = {
	current_python_path = nil, -- Contains path to current python if activated, nil otherwise
	current_venv = nil,       -- Contains path to current venv folder if activated, nil otherwise
	current_bin_path = nil,   -- Keeps track of old system path so we can remove it when adding a new one
	fd_handle = nil,
	path_to_search = nil,
	buffer_dir = nil,
}

M.reload = function(action)
	local act = action or {}

	local dont_refresh_telescope = config.settings.auto_refresh == false and act.force_refresh ~= true
	local ready_for_new_search = M.fd_handle == nil or M.fd_handle:is_closing() == true
	local no_telescope_results = next(telescope.results) == nil

	-- This is needed because Telescope doesnt send the right buffer path when doing a refresh, so we use
	-- the path from the original loading of content to refresh.
	if act.force_refresh ~= true then
		M.buffer_dir = config.get_buffer_dir()
	end
	-- if config.settings.auto_refresh == false and next(telescope.results) ~= nil and opts.force_refresh ~= true then
	if dont_refresh_telescope then
		-- Use cached results
		if no_telescope_results then
			dbg("Refresh telescope since there are no previous results.")
		else
			telescope.show_results()
			return
		end
	end

	if ready_for_new_search then
		telescope.remove_results()

		-- Only search for parent venvs if search option is true
		if config.settings.search == true then
			if act.force_refresh == true then
				if M.path_to_search == nil then
					dbg("No previous search path when asked to refresh results.")
					M.path_to_search = utils.find_parent_dir(M.buffer_dir, config.settings.parents)
					M.find_parent_venvs(M.path_to_search)
				else
					dbg("User refreshed results - buffer_dir is: " .. M.buffer_dir)
					M.path_to_search = utils.find_parent_dir(M.buffer_dir, config.settings.parents)
					M.find_parent_venvs(M.path_to_search)
				end
			else
				M.path_to_search = utils.find_parent_dir(M.buffer_dir, config.settings.parents)
				M.find_parent_venvs(M.path_to_search)
			end
		else
			M.find_other_venvs()
		end
	else
		dbg("Cannot start a new search while old one is running.")
	end
end

-- This gets called as soon as the parent venv search is done.
M.find_other_venvs = function()
	if config.settings.search_workspace == true then
		M.find_workspace_venvs()
	end

	if config.settings.search_venv_managers == true then
		M.find_venv_manager_venvs()
	end

	telescope.show_results()
end
-- Manages the paths to python since they are different on Linux, Mac and Windows
-- systems. The user selects the virtual environment to use in the Telescope picker,
-- but inside the virtual environment, the actual python and its parent directory name
-- differs between Linux, Mac and Windows. This function sets up the correct full path
-- to python, adds it to the system path and sets the VIRTUAL_ENV variable.
M.set_venv_and_system_paths = function(venv_row)
	local sys = system.get_info()
	local venv_path = venv_row.value
	local new_bin_path = venv_path .. sys.path_sep .. sys.python_parent_path
	local venv_python = new_bin_path .. sys.path_sep .. sys.python_name

	M.set_pythonpath(venv_python)
	print("VenvSelect: Activated '" .. venv_python .. "'.")

	local current_system_path = vim.fn.getenv("PATH")
	local prev_bin_path = M.current_bin_path

	-- Remove previous bin path from path
	if prev_bin_path ~= nil then
		current_system_path = string.gsub(current_system_path, utils.escape_pattern(prev_bin_path .. ":"), "")
	end

	-- Add new bin path to path
	local new_system_path = new_bin_path .. ":" .. current_system_path
	vim.fn.setenv("PATH", new_system_path)
	M.current_bin_path = new_bin_path

	-- Set VIRTUAL_ENV
	vim.fn.setenv("VIRTUAL_ENV", venv_path)

	M.current_python_path = venv_python
	M.current_venv = venv_path
end

-- This function removes duplicate results when loading results into telescope
M.prepare_results = function(results)
	local hash = {}
	local res = {}

	for _, v in ipairs(results) do
		if not hash[v.path] then
			res[#res + 1] = v
			hash[v.path] = true
		end
	end

	return res
end

-- Start a search for venvs in all directories under the nstart_dir
-- Async function to search for venvs - it will call VS.show_results() when its done by itself.
M.find_parent_venvs = function(parent_dir)
	dbg("Finding parent venvs in: " .. parent_dir)
	local stdout = vim.loop.new_pipe(false)
	local stderr = vim.loop.new_pipe(false)
	local venv_names = utils.create_fd_venv_names_regexp(config.settings.name)
	local fdconfig = {
		args = { "--absolute-path", "--color", "never", "-HItd", venv_names, parent_dir },
		stdio = { nil, stdout, stderr },
	}

	M.fd_handle = vim.loop.spawn(
		config.settings.fd_binary_name,
		fdconfig,
		vim.schedule_wrap(function() -- on exit
			stdout:read_stop()
			stderr:read_stop()
			stdout:close()
			stderr:close()
			M.find_other_venvs()
			M.fd_handle:close()
		end)
	)
	vim.loop.read_start(stdout, telescope.on_read)
end

-- Hook into lspconfig so we can set the python to use.
M.set_pythonpath = function(python_path)
	vim.cmd.PyrightSetPythonPath(python_path)
	vim.cmd.LspRestart()
end

-- Gets called when user hits enter in the Telescope results dialog
M.activate_venv = function()
	-- dir has path to venv without slash at the end
	local selected_venv = telescope.actions_state.get_selected_entry()
	M.set_venv_and_system_paths(selected_venv)
end

function M.list_pyright_workspace_folders()
	local workspace_folders = {}
	for _, client in pairs(vim.lsp.buf_get_clients()) do
		if client.name == "pyright" then
			for _, folder in pairs(client.workspace_folders or {}) do
				dbg("Found workspace folder: " .. folder.name)
				table.insert(workspace_folders, folder.name)
			end
		end
	end
	return workspace_folders
end

-- Look for workspace venvs
M.find_workspace_venvs = function()
	local workspace_folders = M.list_pyright_workspace_folders()
	local search_path_string = utils.create_fd_search_path_string(workspace_folders)
	if search_path_string:len() ~= 0 then
		local search_path_regexp = utils.create_fd_venv_names_regexp(config.settings.name)
		local cmd = config.settings.fd_binary_name
				.. " -HItd --absolute-path --color never '"
				.. search_path_regexp
				.. "' "
				.. search_path_string

		dbg("Running search for workspace venvs with: " .. cmd)
		local openPop = assert(io.popen(cmd, "r"))
		telescope.add_lines(openPop:lines(), "Workspace")
		openPop:close()
	else
		dbg("Found no workspaces to search for venvs.")
	end
end

-- Look for Poetry and Pipenv managed venv directories and search them.
M.find_venv_manager_venvs = function()
	local paths = { config.settings.poetry_path, config.settings.pipenv_path }
	local search_path_string = utils.create_fd_search_path_string(paths)
	if search_path_string:len() ~= 0 then
		local cmd = config.settings.fd_binary_name
				.. " . -HItd --absolute-path --max-depth 1 --color never "
				.. search_path_string
		dbg("Running search for venv manager venvs with: " .. cmd)
		local openPop = assert(io.popen(cmd, "r"))
		telescope.add_lines(openPop:lines(), "VenvManager")
		openPop:close()
	else
		dbg("Found no venv manager directories to search for venvs.")
	end
end

return M
