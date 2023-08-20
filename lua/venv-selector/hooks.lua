local lspconfig = require("lspconfig")

local M = {}

--- @alias NvimLspClient table
--- @alias LspClientCallback fun(client: NvimLspClient): nil
--- @type fun(name: string, callback: LspClientCallback): nil
local function execute_for_client(name, callback)
  local dbg = require("venv-selector.utils").dbg
  local client = vim.lsp.get_active_clients({ name = name })[1]

  if not client then
    dbg("No client named: " .. name .. " found")
    return
  end

  callback(client)
end

--- @alias VenvChangedHook fun(venv_path: string, venv_python: string): nil
--- @type VenvChangedHook
M.pyright_hook = function(_, venv_python)
  execute_for_client("pyright", function(pyright)
    local settings = vim.deepcopy(pyright.config.settings)
    lspconfig.pyright.setup({
      settings = settings,
      before_init = function(_, c)
        c.settings.python.pythonPath = venv_python
      end,
    })
  end)
end

--- @type VenvChangedHook
M.pylance_hook = function(_, venv_python)
  execute_for_client("pylance", function(pylance)
    local settings = vim.deepcopy(pylance.config.settings)
    lspconfig.pylance.setup({
      settings = settings,
      before_init = function(_, c)
        c.settings.python.pythonPath = venv_python
      end,
    })
  end)
end

--- @type VenvChangedHook
M.pylsp_hook = function(venv_path, _)
  local utils = require("venv-selector.utils")
  local system = require("venv-selector.system")
  local sys = system.get_info()

  execute_for_client("pylsp", function(pylsp)
    local settings = vim.deepcopy(pylsp.config.settings)
    local lib_path = venv_path .. sys.path_sep .. "lib" .. sys.path_sep
    local site_packages = nil

    for filename, _ in vim.fs.dir(lib_path) do
      if utils.starts_with(filename, "python") then
        site_packages = lib_path .. sys.path_sep .. filename .. sys.path_sep .. "site-packages"
      end
    end

    if site_packages == nil then
      utils.dbg("Failed to find site packages directory in: " .. lib_path)
      return
    end

    lspconfig.pylsp.setup({
      settings = settings,
      before_init = function(_, c)
        local jedi_config = settings.pylsp.plugins.jedi or {}

        if jedi_config.extra_paths ~= nil then
          table.insert(jedi_config.extra_paths, site_packages)
        else
          jedi_config["extra_paths"] = { site_packages }
        end

        c.settings.pylsp.plugins.jedi = jedi_config
      end,
    })
  end)
end

return M
