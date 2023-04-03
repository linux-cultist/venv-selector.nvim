local system = require("venv-selector.system")
local utils = require("venv-selector.utils")
local lspconfig = require("lspconfig")

local M = {}

M.current_bin_path = nil -- Keeps track of old system path so we can remove it when adding a new one

-- Manages the paths to python since they are different on Linux, Mac and Windows
-- systems. The user selects the virtual environment to use in the Telescope picker,
-- but inside the virtual environment, the actual python and its parent directory name
-- differs between Linux, Mac and Windows. This function sets up the correct full path
-- to python, adds it to the system path and sets the VIRTUAL_ENV variable.
M.set_venv_and_paths = function(dir)
	local sys = system.get_info()
	local new_bin_path = dir .. sys.path_sep .. sys.python_parent_path
	local venv_python = new_bin_path .. sys.path_sep .. sys.python_name

	M.set_pythonpath(venv_python)
	print("Pyright now using '" .. venv_python .. "'.")

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
	vim.fn.setenv("VIRTUAL_ENV", dir)
end

-- Start a search for venvs in all directories under the start_dir
M.find_venvs = function(start_dir)
	M.search_subdirectories_for_venvs(start_dir)
end

-- Async function to search for venvs - it will call VS.show_results() when its done by itself.
M.search_subdirectories_for_venvs = function(start_dir)
	local stdout = vim.loop.new_pipe(false)
	local stderr = vim.loop.new_pipe(false)

	local telescope = require("venv-selector.telescope")
	local venv_names = utils.create_fd_venv_names_regexp(config.settings.name)
	local fdconfig = {
		args = { "--color", "never", "-HItd", venv_names, start_dir },
		stdio = { nil, stdout, stderr },
	}

	handle = vim.loop.spawn(
		"fd",
		fdconfig,
		vim.schedule_wrap(function() -- on exit
			stdout:read_stop()
			stderr:read_stop()
			stdout:close()
			stderr:close()
			handle:close()
			telescope.show_results()
		end)
	)

	vim.loop.read_start(stdout, telescope.on_results)
end

-- Hook into lspconfig so we can set the python to use.
M.set_pythonpath = function(python_path)
	lspconfig.pyright.setup({
		before_init = function(_, config)
			config.settings.python.pythonPath = python_path
		end,
	})
end

-- Gets called when user hits enter in the Telescope results dialog
M.activate_venv = function(prompt_bufnr)
	-- dir has path to venv without slash at the end
	local telescope = require("venv-selector.telescope")
	local dir = telescope.actions_state.get_selected_entry().value

	if dir ~= nil then
		telescope.actions.close(prompt_bufnr)
		M.set_venv_and_paths(dir)
	end
end

-- Look for Poetry and Pipenv managed venv directories and search them.
M.find_venv_manager_venvs = function()
	local results = {}
	local paths = { config.settings.poetry_path, config.settings.pipenv_path }
	local search_path_string = utils.create_fd_search_path_string(paths)

	local openPop = assert(io.popen("fd . -HItd --max-depth 1 --color never " .. search_path_string, "r"))
	local output = openPop:lines()
	for line in output do
		table.insert(results, utils.remove_last_slash(line))
	end

	openPop:close()
	return results
end

return M
