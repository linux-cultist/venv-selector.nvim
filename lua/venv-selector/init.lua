local M = {}
M._config = {}
M._results = {}

local finders = require("telescope.finders")
local conf = require("telescope.config").values
local pickers = require("telescope.pickers")
local actions_state = require("telescope.actions.state")
local actions = require("telescope.actions")

M.activate_venv = function(prompt_bufnr)
	local dir = actions_state.get_selected_entry().value
	actions.close(prompt_bufnr)
	local venv_python = dir .. "bin/python"
	print("Pyright now using '" .. venv_python .. "'.")
	local lspconfig = require("lspconfig")
	lspconfig.pyright.setup({
		before_init = function(_, config)
			config.settings.python.pythonPath = venv_python
		end,
	})
end

M.on_results = function(err, data)
	if err then
		print("error")
	end

	if data then
		local vals = vim.split(data, "\n")
		for _, d in pairs(vals) do
			if d == "" then
				goto continue
			end
			table.insert(M._results, d)
			::continue::
		end
	end
end

M.display_results = function(start_dir)
	local overrides = {}
	local opts = {
		layout_strategy = "vertical",
		layout_config = {
			height = 20,
			width = 100,
			prompt_position = "top",
		},
		sorting_strategy = "ascending",
		prompt_title = "Virtual environments found under " .. start_dir,
		results_title = "Venvs",
		finder = finders.new_table(M._results),
		sorter = conf.file_sorter({}),
		attach_mappings = function(prompt_bufnr, map)
			map("i", "<CR>", M.activate_venv)
			return true
		end,
	}

	pickers.new(overrides, opts):find()
end

M.find2 = function(start_dir)
	M._results = vim.fs.find(M._config.name, { type = "directory", limit = 100, path = start_dir })
	M.display_results(start_dir)
end

M.find = function()
	local start_dir = M.find_starting_dir(M._config.path, M._config.parents)
	local uv = vim.loop
	local stdout = uv.new_pipe(false) -- create file descriptor for stdout
	local stderr = uv.new_pipe(false) -- create file descriptor for stderr
	handle = uv.spawn(
		"fd",
		{
			args = { "--color", "never", "-HItd", "-g", "venv", start_dir },
			stdio = { nil, stdout, stderr },
		},
		vim.schedule_wrap(function() -- on exit
			stdout:read_stop()
			stderr:read_stop()
			stdout:close()
			stderr:close()
			handle:close()
			M.display_results(start_dir)
		end)
	)

	uv.read_start(stdout, M.on_results)
	uv.read_start(stderr, M.on_results)
end

M.find_starting_dir = function(dir, limit)
	for subdir in vim.fs.parents(dir) do
		if vim.fn.isdirectory(subdir) then
			if limit > 0 then
				return M.find_starting_dir(subdir, limit - 1)
			end
		end
	end

	return dir
end

M.merge = function(t1, t2)
	if t2 == nil then
		return t1
	end

	for k, v in pairs(t2) do
		if type(v) == "table" then
			t1[k] = M.merge(t1[k], t2[k])
		else
			t1[k] = v
		end
	end

	return t1
end

M.search = function(config)
	local defaults = { name = "venv", parents = 4, path = vim.fn.getcwd() }
	M._config = M.merge(defaults, config)
	M._results = {}
	M.find()
end

M.setup = function()
end

return M

-- M.setup()
-- M.search()
