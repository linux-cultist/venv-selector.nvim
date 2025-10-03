local path = require("venv-selector.path")
local config = require("venv-selector.config")
local log = require("venv-selector.logger")

local M = {}

path.current_source = nil -- contains the name of the search, like anaconda, pipx etc.

function M.stop_lsp_servers()
    local hooks = require("venv-selector.config").user_settings.hooks
    for _, hook in pairs(hooks) do
        hook(nil, nil)
    end
end

function M.set_source(source)
    log.debug('Setting require("venv-selector").source() to \'' .. source .. "'")
    path.current_source = source
end

--- Activate a virtual environment.
---
--- This function will update the paths and environment variables to the selected virtual environment,
--- and inform the lsp servers about the change.
---@param python_path string The path to the python executable in the virtual environment.
---@param type string The type of the virtual environment. This is used to determine which environment variable to set (e.g. conda or venv)
---@param check_lsp boolean Whether to check if lsp servers are running before activating the virtual environment.
---@return boolean activated Whether the virtual environment was activated successfully.
function M.activate(python_path, type, check_lsp)
    if python_path == nil then
        return false
    end

    if vim.fn.filereadable(python_path) ~= 1 then
        log.debug("Venv `" .. python_path .. "` doesnt exist so cant activate it.")
        return false
    end

    -- Set the below two variables as quick as possible since its used in sorting results in telescope
    path.current_python_path = python_path
    path.current_venv_path = path.get_base(python_path)
    path.current_type = type

    -- Inform lsp servers
    local count = 0
    local hooks = require("venv-selector.config").user_settings.hooks
    for _, hook in pairs(hooks) do
        count = count + hook(python_path, type)
    end

    if check_lsp and count == 0 and config.user_settings.options.require_lsp_activation == true then
        local message =
        "No python lsp servers are running. Please open a python file and then select a venv to activate."
        vim.notify(message, vim.log.levels.INFO, { title = "VenvSelect" })
        log.info(message)
        return false
    end

    local cache = require("venv-selector.cached_venv")
    cache.save(python_path, type)

    M.update_paths(python_path, type)

    local on_venv_activate_callback = config.user_settings.options.on_venv_activate_callback
    if on_venv_activate_callback ~= nil then
        log.debug("Calling on_venv_activate_callback() function")
        on_venv_activate_callback()
    end

    return true
end

function M.update_paths(venv_path, type)
    path.add(path.get_base(venv_path))
    path.update_python_dap(venv_path)
    path.save_selected_python(venv_path)

    -- Handle environment variables based on venv type
    if type == "uv" then
        -- Don't set VIRTUAL_ENV for UV environments as they are managed by UV
        M.unset_env("VIRTUAL_ENV")
        M.unset_env("CONDA_PREFIX")
    elseif type == "anaconda" then
        M.unset_env("VIRTUAL_ENV")
        local base_path

        if vim.fn.has("Win32") == 1 then
            base_path = path.get_base(venv_path)
        else
            base_path = path.get_base(path.get_base(venv_path))
        end

        M.set_env(base_path, "CONDA_PREFIX")
    else
        local base_path = path.get_base(path.get_base(venv_path))
        M.unset_env("CONDA_PREFIX")
        M.set_env(base_path, "VIRTUAL_ENV")
    end
end

function M.set_env(env_variable_value, env_variable_name)
    if config.user_settings.options.set_environment_variables == true then
        vim.fn.setenv(env_variable_name, env_variable_value)
        log.debug("$" .. env_variable_name .. " set to " .. env_variable_value)
    end
end

function M.unset_env(env_variable_name)
    if config.user_settings.options.set_environment_variables == true then
        if vim.fn.getenv(env_variable_name) ~= nil then
            vim.fn.setenv(env_variable_name, nil)
            log.debug("$" .. env_variable_name .. " has been unset.")
        end
    end
end

function M.unset_env_variables()
    vim.fn.setenv("VIRTUAL_ENV", nil)
    vim.fn.setenv("CONDA_PREFIX", nil)
end

return M
