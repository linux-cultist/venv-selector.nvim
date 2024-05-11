local path = require("venv-selector.path")
local utils = require("venv-selector.utils")
local config = require("venv-selector.config")

local M = {}


function M.activate(hooks, selected_entry)
    local python_path = selected_entry.path
    local venv_type = selected_entry.type

    if python_path ~= nil then
        local count = 0
        for _, hook in pairs(hooks) do
            count = count + hook(python_path)
        end

        if count == 0 then
            print("No python lsp servers are running. Please open a python file and then select a venv to activate.")
            return false
        else
            local cache = require("venv-selector.cached_venv")
            cache.save(python_path, venv_type)
            return true
        end

        config.user_settings.options.on_venv_activate_callback()
    end
end

function M.activate_from_cache(settings, venv_info)
    dbg("Activating venv from cache")
    local venv = require("venv-selector.venv")
    local python_path = venv_info.value
    local venv_type = venv_info.type

    for _, hook in pairs(settings.hooks) do
        hook(python_path)
    end

    path.add(path.get_base(python_path.value))

    if venv_type ~= nil and venv_type == "anaconda" then
        venv.unset_env("VIRTUAL_ENV")
        venv.set_env(python_path, "CONDA_PREFIX")
    else
        venv.unset_env("CONDA_PREFIX")
        venv.set_env(python_path, "VIRTUAL_ENV")
    end

    path.update_python_dap(python_path)
    path.save_selected_python(python_path)
end

function M.set_env(python_path, env_variable_name)
    if config.user_settings.options.set_environment_variables == true then
        local env_path = path.get_base(path.get_base(python_path))
        if env_path ~= nil then
            vim.fn.setenv(env_variable_name, env_path)
            dbg("$" .. env_variable_name .. " set to " .. env_path)
        end
    end
end

function M.unset_env(env_variable_name)
    if config.user_settings.options.set_environment_variables == true then
        if vim.fn.getenv(env_variable_name) ~= nil then
            vim.fn.setenv(env_variable_name, nil)
            dbg("$" .. env_variable_name .. " has been unset.")
        end
    end
end

return M
