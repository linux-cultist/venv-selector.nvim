local telescope = require("venv-selector.telescope")
local utils = require("venv-selector.utils")
local lspconfig = require("lspconfig")

local VS = {}

VS._config = {}
VS._results = {}
VS._os = nil
VS._current_bin_path = nil

VS._default_config = {
  search = true,
  name = "venv",
  parents = 2,      -- Go max this many directories up from the current opened buffer
  poetry_path = nil, -- Added by setup function
  pipenv_path = nil, -- Added by setup function
}

VS.set_pythonpath = function(python_path)
  lspconfig.pyright.setup({
    before_init = function(_, config)
      config.settings.python.pythonPath = python_path
    end,
  })
end

VS.activate_venv = function(prompt_bufnr)
  -- dir has path to venv without slash at the end
  local dir = telescope.actions_state.get_selected_entry().value

  local venv_python
  local new_bin_path

  if dir ~= nil then
    telescope.actions.close(prompt_bufnr)
    if VS._os == "Linux" or VS._os == "Darwin" then
      new_bin_path = dir .. "/bin"
      venv_python = new_bin_path .. "/python"
    else
      new_bin_path = dir .. "\\Scripts"
      venv_python = new_bin_path .. "\\python.exe"
    end

    print("Pyright now using '" .. venv_python .. "'.")
    VS.set_pythonpath(venv_python)

    local current_system_path = vim.fn.getenv("PATH")
    local prev_bin_path = VS._current_bin_path

    -- Remove previous bin path from path
    if prev_bin_path ~= nil then
      current_system_path = string.gsub(current_system_path, utils.escape_pattern(prev_bin_path .. ":"), "")
    end

    -- Add new bin path to path
    local new_system_path = new_bin_path .. ":" .. current_system_path
    vim.fn.setenv("PATH", new_system_path)
    VS._current_bin_path = new_bin_path

    -- Set VIRTUAL_ENV
    vim.fn.setenv("VIRTUAL_ENV", dir)
  end
end

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
      table.insert(VS._results, utils.remove_last_slash(rows))
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
      local openPop = assert(io.popen("fd . -HItd --max-depth 1 --color never " .. v, "r"))
      local output = openPop:lines()
      for line in output do
        table.insert(VS._results, utils.remove_last_slash(line))
      end

      openPop:close()
    end
  end
end

VS.async_find = function(path_to_search)
  VS._results = {}
  local config = VS._config
  -- utils.print_table(config)
  VS.search_manager_paths()
  if VS._config.search == false then
    VS.display_results()
    return
  end
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

  VS._os = vim.loop.os_uname().sysname

  if VS._os == "Linux" then
    VS._default_config.poetry_path = "~/.cache/pypoetry/virtualenvs"
    VS._default_config.pipenv_path = "~/.local/share/virtualenvs"
  elseif VS._os == "Darwin" then
    VS._default_config.poetry_path = "~/Library/Caches/pypoetry/virtualenvs"
    VS._default_config.pipenv_path = "~/.local/share/virtualenvs"
  else -- Windows
    VS._default_config.poetry_path = "%APPDATA%\\pypoetry\\virtualenvs"
    VS._default_config.pipenv_path = "~\\virtualenvs"
  end

  VS._config = vim.tbl_deep_extend("force", VS._default_config, config)
  -- utils.print_table(VS._config)
  VS.setup_user_command()
end

return VS
-- VS.setup()
