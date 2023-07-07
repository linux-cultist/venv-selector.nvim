local venv = require("venv-selector.venv")
local config = require("venv-selector.config")
local user_commands = require("venv-selector.user_commands")
local dbg = require("venv-selector.utils").dbg
local hooks = require("venv-selector.hooks")
local utils = require("venv-selector.utils")

M = {
  -- Called by user when using the plugin.
  setup = function(settings)
    -- Let user config overwrite any default config options.
    config.settings = vim.tbl_deep_extend("force", config.default_settings, settings or {})
    dbg(config.settings)

    -- Create the VenvSelect command.
    user_commands.setup_user_commands("VenvSelect", M.reload, "Use VenvSelect to activate a venv")
    user_commands.setup_user_commands(
      "VenvSelectCached",
      M.retrieve_from_cache,
      "Use VenvSelect to retrieve a venv from cache"
    )

    -- Check if the user has the requirements to run VenvSelect
    if utils.fd_or_fdfind_exists() == false then
      utils.error("Missing requirement: VenvSelect needs 'fd' to be installed: https://github.com/sharkdp/fd.")
    end
  end,
  -- Gets the system path to current active python in the venv (or nil if its not activated)
  get_active_path = function()
    return venv.current_python_path
  end,
  -- Gets the system path to the current active venv (or nil if its not activated)
  get_active_venv = function()
    return venv.current_venv
  end,
  -- The main function runs when user executes VenvSelect command
  reload = function()
    venv.reload()
  end,
  deactivate_venv = function()
    venv.deactivate_venv()
  end,
  retrieve_from_cache = function()
    return venv.retrieve_from_cache()
  end,
  hooks = {
    pyright = hooks.pyright_hook,
    pylsp = hooks.pylsp_hook,
  },
}

return M
