local path = require 'venv-selector.path'
local config = require 'venv-selector.config'
local log = require 'venv-selector.logger'

local M = {}

M.current_source = nil -- contains the name of the search, like anaconda, pipx etc.

function M.stop_lsp_servers()
    local hooks = require('venv-selector.config').default_settings.hooks
    for _, hook in pairs(hooks) do
        hook(nil)
    end
end

function M.activate(hooks, selected_entry)
    local python_path = selected_entry.path
    local venv_type = selected_entry.type
    local source = selected_entry.source
    local on_venv_activate_callback = config.default_settings.options.on_venv_activate_callback

    if python_path ~= nil then
        log.debug('Telescope entry selected by user: ', selected_entry)
        local count = 0
        for _, hook in pairs(hooks) do
            count = count + hook(python_path)
        end

        if count == 0 then
            local message =
                'No python lsp servers are running. Please open a python file and then select a venv to activate.'
            vim.notify(message, vim.log.levels.INFO, { title = 'VenvSelect' })
            log.info(message)
            return false
        else
            local cache = require 'venv-selector.cached_venv'
            cache.save(python_path, venv_type, source)
            if on_venv_activate_callback ~= nil then
                M.current_source = source
                log.debug('Setting require("venv-selector").source() to \'' .. source .. "'")
                log.debug 'Calling on_venv_activate_callback() function'
                on_venv_activate_callback()
            end
            return true
        end
    end
end

function M.activate_from_cache(settings, venv_info)
    log.debug 'Activating venv from cache'

    -- Set the below two variables as quick as possible since its used in sorting results in telescope
    -- and if the user is quick to open the telescope before lsp has activated, the selected
    -- venv wont be displayed otherwise.
    path.current_python_path = venv_info.value
    path.current_venv_path = path.get_base(venv_info.value)

    local venv = require 'venv-selector.venv'
    local python_path = venv_info.value
    local venv_type = venv_info.type
    local venv_source = venv_info.source
    local on_venv_activate_callback = config.default_settings.options.on_venv_activate_callback
    for _, hook in pairs(settings.hooks) do
        hook(python_path)
    end

    if venv_type ~= nil and venv_type == 'anaconda' then
        venv.unset_env 'VIRTUAL_ENV'
        venv.set_env(python_path, 'CONDA_PREFIX')
    else
        venv.unset_env 'CONDA_PREFIX'
        venv.set_env(python_path, 'VIRTUAL_ENV')
    end

    path.update_python_dap(python_path)
    path.save_selected_python(python_path)
    path.add(path.get_base(python_path))

    if on_venv_activate_callback ~= nil then
        M.current_source = venv_source
        log.debug('Setting require("venv-selector").source() to \'' .. venv_source .. '"')
        log.debug 'Calling on_venv_activate_callback() function'
        on_venv_activate_callback()
    end
end

function M.set_env(python_path, env_variable_name)
    if config.default_settings.options.set_environment_variables == true then
        local env_path = path.get_base(path.get_base(python_path))
        if env_path ~= nil then
            vim.fn.setenv(env_variable_name, env_path)
            log.debug('$' .. env_variable_name .. ' set to ' .. env_path)
        end
    end
end

function M.unset_env(env_variable_name)
    if config.default_settings.options.set_environment_variables == true then
        if vim.fn.getenv(env_variable_name) ~= nil then
            vim.fn.setenv(env_variable_name, nil)
            log.debug('$' .. env_variable_name .. ' has been unset.')
        end
    end
end

function M.unset_env_variables()
    vim.fn.setenv('VIRTUAL_ENV', nil)
    vim.fn.setenv('CONDA_PREFIX', nil)
end

return M
