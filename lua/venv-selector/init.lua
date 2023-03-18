local telescope = require("venv-selector.telescope")
local utils = require("venv-selector.utils")
local lspconfig = require("lspconfig")

local VS = {}

VS._config = {}
VS._results = {}

VS._default_config = {
	name = "venv",
	parents = 5, -- Go max this many directories up from the current opened buffer
	poetry_path = "$HOME/.cache/pypoetry/virtualenvs",
	pipenv_path = "$HOME/.local/share/virtualenvs",
}

VS.set_pythonpath = function(python_path)
	lspconfig.pyright.setup({
		before_init = function(_, config)
			config.settings.python.pythonPath = python_path
		end,
	})
end

VS.activate_venv = function(prompt_bufnr)
	local dir = telescope.actions_state.get_selected_entry().value

	if dir ~= nil then
		telescope.actions.close(prompt_bufnr)
		local venv_python = dir .. "bin/python"
		print("Pyright now using '" .. venv_python .. "'.")
		VS.set_pythonpath(venv_python)
	end
end

VS.on_results = function(err, data)
	if err then
		print(err)
	end

	if data then
		local vals = vim.split(data, "\n", {})
		for _, rows in pairs(vals) do
			if rows == "" then
				goto continue
			end
			table.insert(VS._results, rows)
			::continue::
		end
	end
end

VS.display_results = function()
	local opts = {
		layout_strategy = "vertical",
		layout_config = {
			height = 20,
			width = 100,
			prompt_position = "top",
		},
		sorting_strategy = "descending",
		prompt_title = "Python virtual environments",
		finder = telescope.finders.new_table(VS._results),
		sorter = telescope.conf.file_sorter({}),
		attach_mappings = function(bufnr, map)
			map("i", "<CR>", VS.activate_venv)
			return true
		end,
	}

	telescope.pickers.new({}, opts):find()
end

VS.search_manager_paths = function(paths)
	local paths = { VS._config.poetry_path, VS._config.pipenv_path }
	for k, v in pairs(paths) do
		v = vim.fn.expand(v)
		if vim.fn.isdirectory(v) ~= 0 then
			local openPop = assert(io.popen("fd . " .. v .. " --max-depth 1 --color never", "r"))
			local output = openPop:read()
			openPop:close()
			table.insert(VS._results, output)
		end
	end
end

VS.async_find = function(path_to_search)
	VS._results = {}
	local config = VS._config
	-- utils.print_table(config)
	VS.search_manager_paths()
	local start_dir = VS.find_starting_dir(path_to_search, config.parents)
	-- print("Start dir set to: " .. start_dir)
	local stdout = vim.loop.new_pipe(false) -- create file descriptor for stdout
	local stderr = vim.loop.new_pipe(false) -- create file descriptor for stderr

	local fdconfig = {
		args = { "--color", "never", "-HItd", "-g", VS._config.name, start_dir },
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
			VS.display_results()
		end)
	)

	vim.loop.read_start(stdout, VS.on_results)
end

VS.find_starting_dir = function(dir, limit)
	for subdir in vim.fs.parents(dir) do
		if vim.fn.isdirectory(subdir) then
			if limit > 0 then
				return VS.find_starting_dir(subdir, limit - 1)
			else
				break
			end
		end
	end

	return dir
end

VS.setup_user_command = function()
	vim.api.nvim_create_user_command("VenvSelect", function()
		-- If there is a path in VS._config, use that one - it comes from user plugin settings.
		-- If not, use current open buffer directory.
		local path_to_search

		if VS._config.path == nil then
			path_to_search = vim.fn.expand("%:p:h")
		else
			path_to_search = VS._config.path
		end

		-- print("Using path: " .. path_to_search)
		VS.async_find(path_to_search)
	end, { desc = "Use VenvSelector to activate a venv" })
end

VS.setup = function(config)
	if config == nil then
		config = {}
	end

	VS._config = vim.tbl_deep_extend("force", VS._default_config, config)
	-- utils.print_table(VS._config)
	VS.setup_user_command()
end

return VS
-- VS.setup()
