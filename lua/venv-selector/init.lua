local telescope = require("venv-selector.telescope")
local utils = require("venv-selector.utils")
local lspconfig = require("lspconfig")

local VS = {
	config = {},
	results = {},
	os = utils.get_system_differences(),
	current_bin_path = nil,
}

-- Default settings if user is not setting anything in setup() call
VS.default_config = {
	search = true,
	name = "venv",
	parents = 2, -- When search is true, go this many directories up from the current opened buffer
	poetry_path = utils.get_venv_manager_default_path("Poetry"),
	pipenv_path = utils.get_venv_manager_default_path("Pipenv"),
}

-- Hook into lspconfig so we can set the python to use.
VS.set_pythonpath = function(python_path)
	lspconfig.pyright.setup({
		before_init = function(_, config)
			config.settings.python.pythonPath = python_path
		end,
	})
end

-- Manages the paths to python since they are different on Linux, Mac and Windows
-- systems. The user selects the virtual environment to use in the Telescope picker,
-- but inside the virtual environment, the actual python and its parent directory name
-- differs between Linux, Mac and Windows. This function sets up the correct full path
-- to python, adds it to the system path and sets the VIRTUAL_ENV variable.
VS.set_venv_and_paths = function(dir)
	local new_bin_path = dir .. VS.os.path_sep .. VS.os.python_parent_path
	local venv_python = new_bin_path .. VS.os.path_sep .. VS.os.python_name

	VS.set_pythonpath(venv_python)
	print("Pyright now using '" .. venv_python .. "'.")

	local current_system_path = vim.fn.getenv("PATH")
	local prev_bin_path = VS.current_bin_path

	-- Remove previous bin path from path
	if prev_bin_path ~= nil then
		current_system_path = string.gsub(current_system_path, utils.escape_pattern(prev_bin_path .. ":"), "")
	end

	-- Add new bin path to path
	local new_system_path = new_bin_path .. ":" .. current_system_path
	vim.fn.setenv("PATH", new_system_path)
	VS.current_bin_path = new_bin_path

	-- Set VIRTUAL_ENV
	vim.fn.setenv("VIRTUAL_ENV", dir)
end

-- Gets called when user hits enter in the Telescope results dialog
VS.activate_venv = function(prompt_bufnr)
	-- dir has path to venv without slash at the end
	local dir = telescope.actions_state.get_selected_entry().value

	if dir ~= nil then
		telescope.actions.close(prompt_bufnr)
		VS.set_venv_and_paths(dir)
	end
end

-- Gets called on results from the async search and adds the findings
-- to VS._results to show when its done.
VS.on_results = function(err, data)
	if err then
		print("Error:" .. err)
	end

	if data then
		local vals = vim.split(data, "\n", {})
		for _, rows in pairs(vals) do
			if rows == "" then
				goto continue
			end
			table.insert(VS.results, utils.remove_last_slash(rows))
			::continue::
		end
	end
end

-- Shows the results from the search in a Telescope picker.
VS.show_results = function()
	local opts = {
		layout_strategy = "vertical",
		layout_config = {
			height = 20,
			width = 100,
			prompt_position = "top",
		},
		sorting_strategy = "descending",
		prompt_title = "Python virtual environments",
		finder = telescope.finders.new_table(VS.results),
		sorter = telescope.conf.file_sorter({}),
		attach_mappings = function(bufnr, map)
			map("i", "<CR>", VS.activate_venv)
			return true
		end,
	}

	telescope.pickers.new({}, opts):find()
end

-- Look for Poetry and Pipenv managed venv directories and search them.
VS.find_venv_manager_venvs = function()
	local results = {}
	local paths = { VS.config.poetry_path, VS.config.pipenv_path }
	local search_path_string = utils.create_fd_search_path_string(paths)

	local openPop = assert(io.popen("fd . -HItd --max-depth 1 --color never " .. search_path_string, "r"))
	local output = openPop:lines()
	for line in output do
		table.insert(results, utils.remove_last_slash(line))
	end

	openPop:close()
	return results
end

-- Async function to search for venvs - it will call VS.show_results() when its done by itself.
VS.search_subdirectories_for_venvs = function(start_dir)
	local stdout = vim.loop.new_pipe(false)
	local stderr = vim.loop.new_pipe(false)

	local venv_names = utils.create_fd_venv_names_regexp(VS.config.name)
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
			VS.show_results()
		end)
	)

	vim.loop.read_start(stdout, VS.on_results)
end

-- Start a search for venvs in all directories under the start_dir
VS.find_venvs = function(start_dir)
	VS.search_subdirectories_for_venvs(start_dir)
end

-- Go up in the directory tree "limit" amount of times, and then returns the path.
VS.find_parent_dir = function(dir, limit)
	for subdir in vim.fs.parents(dir) do
		if vim.fn.isdirectory(subdir) then
			if limit > 0 then
				return VS.find_parent_dir(subdir, limit - 1)
			else
				break
			end
		end
	end

	return dir
end

-- Gets the search path supplied by the user in the setup function, or use current open buffer directory.
VS.get_search_path_from_config = function()
	if VS.config.path == nil then
		return vim.fn.expand("%:p:h")
	end

	return VS.config.path
end

-- The main function runs when user executes VenvSelect command
VS.main = function()
	-- Start with getting venv manager venvs if they exist (Poetry, Pipenv)
	VS.results = VS.find_venv_manager_venvs()

	-- Only search for other venvs if search option is true
	if VS.config.search == true then
		local path_to_search = VS.get_search_path_from_config()
		local start_dir = VS.find_parent_dir(path_to_search, VS.config.parents)
		VS.find_venvs(start_dir) -- The results will show up when search is done - dont call VS.show_results() here.
		return
	end

	VS.show_results()
end

-- Connect user command to main function
VS.setup_user_command = function()
	vim.api.nvim_create_user_command("VenvSelect", VS.main, { desc = "Use VenvSelector to activate a venv" })
end

-- Called by user when using the plugin.
VS.setup = function(config)
	-- If no config sent in by user, use empty lua table and later extend it with default options.
	if config == nil then
		config = {}
	end

	-- Let user config overwrite any default config options.
	VS.config = vim.tbl_deep_extend("force", VS.default_config, config)

	-- Create the VenvSelect command.
	VS.setup_user_command()
end

return VS
-- VS.setup()
