local telescope = require("venv-selector.telescope")
local utils = require("venv-selector.utils")
local lspconfig = require("lspconfig")

local VS = {}

VS._config = {}
VS._results = {}
VS._default_config = { name = "venv", parents = 2, children = 100 }

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
		prompt_title = "Environments matching '" .. VS._config.name .. "' under " .. VS._start_dir,
		results_title = "Venvs",
		finder = telescope.finders.new_table(VS._results),
		sorter = telescope.conf.file_sorter({}),
		attach_mappings = function(bufnr, map)
			map("i", "<CR>", VS.activate_venv)
			return true
		end,
	}

	telescope.pickers.new({}, opts):find()
end

VS.slow_find = function()
	VS._results =
		vim.fs.find(VS._config.name, { type = "directory", limit = VS._config.parents, path = VS._config.path })
	VS.display_results()
end

VS.async_find = function()
	VS._results = {}
	local config = VS._config
	-- utils.print_table(config)
	VS._start_dir = VS.find_starting_dir(config.path, config.parents)
	local stdout = vim.loop.new_pipe(false) -- create file descriptor for stdout
	local stderr = vim.loop.new_pipe(false) -- create file descriptor for stderr

	local fdconfig = {
		args = { "--color", "never", "-HItd", "--max-depth", config.children + 1, "-g", VS._config.name, VS._start_dir },
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
			end
		end
	end

	return dir
end

VS.setup_user_command = function()
	vim.api.nvim_create_user_command("VenvSelect", function()
		-- If there is a path in VS._config, use that one - it comes from user plugin settings.
		-- If not, use current open buffer directory.

		if VS._config.path == nil then
			VS._config.path = vim.fn.expand("%:p:h")
		end

		VS.async_find()
	end, { desc = "Use VenvSelector to activate a venv" })
end

VS.setup = function(config)
	-- While developing
	-- config = { name = "*", parents = 0, children = 0, path = "/home/cado/.cache/pypoetry/virtualenvs" }

	-- Remove after
	if config == nil then
		config = {}
	end

	VS._config = vim.tbl_deep_extend("force", VS._default_config, config)
	-- utils.print_table(VS._config)
	VS.setup_user_command()
end

return VS
-- VS.setup()
