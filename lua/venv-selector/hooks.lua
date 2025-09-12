local log = require("venv-selector.logger")

---@alias venv-selector.Hook fun(venv_python: string, env_type: string?): nil

--[[
Example: Custom hook with custom settings format

function my_custom_lsp_hook(venv_python, env_type)
  -- Only configure if there are running clients
  local running_clients = vim.lsp.get_clients({ name = 'my_custom_lsp' })
  if #running_clients == 0 then
    return 0  -- Return 0 when no clients to configure
  end

  -- Update the LSP config with new Python path
  vim.lsp.config('my_custom_lsp', {
    settings = {
      customLsp = {
        pythonExecutable = venv_python,
        workspaceFolder = venv_python and vim.fn.fnamemodify(venv_python, ":h:h") or nil,
        enableFeatures = venv_python ~= nil,
      }
    }
  })

  -- Restart the LSP to apply new settings
  vim.lsp.enable('my_custom_lsp', false)
  vim.defer_fn(function()
    vim.lsp.enable('my_custom_lsp', true)
  end, 500)

  if venv_python == nil then
    print("Cleared Python path from my_custom_lsp")
  else
    print("Configured my_custom_lsp with: " .. venv_python)
  end
  return 1
end

Usage in setup:
require('venv-selector').setup({
  hooks = {
    hooks.basedpyright_hook,
    my_custom_lsp_hook,  -- Your custom hook
  }
})
--]]

local M = {}

M.notifications_memory = {}

-- Track which LSP configs have been activated to prevent redundant operations
-- Format: { lsp_name = venv_python_path }
M.activated_configs = {}





-- Generic settings wrapper for most Python LSP servers
local function generic_python_settings_wrapper(venv_python, env_type)
    log.debug("generic_python_settings_wrapper called with: " ..
    (venv_python or "nil") .. ", env_type: " .. (env_type or "nil"))
    if not venv_python then
        return {
            python = { pythonPath = vim.NIL, venv = vim.NIL, venvPath = vim.NIL },
            cmd_env = {}
        }
    end
    local venv_path = vim.fn.fnamemodify(venv_python, ":h:h")
    local settings = {
        python = {
            pythonPath = venv_python,
            venv = vim.fn.fnamemodify(venv_path, ":t"),
            venvPath = venv_path
        },
        cmd_env = {}
    }

    -- Set appropriate environment variable based on environment type
    if env_type == "anaconda" then
        settings.cmd_env.CONDA_PREFIX = venv_path
        settings.cmd_env.VIRTUAL_ENV = ""  -- Clear VIRTUAL_ENV for conda
        log.debug("Setting CONDA_PREFIX for conda environment: " .. venv_path .. " and clearing VIRTUAL_ENV")
    else
        settings.cmd_env.VIRTUAL_ENV = venv_path
        settings.cmd_env.CONDA_PREFIX = ""  -- Clear CONDA_PREFIX for regular venv
        log.debug("Setting VIRTUAL_ENV for regular environment: " .. venv_path .. " and clearing CONDA_PREFIX")
    end

    log.debug("generic_python_settings_wrapper returning settings:", settings)
    return settings
end

-- LSP-specific configuration for different Python language servers
local LSP_CONFIGS = {
    basedpyright = {
        settings_wrapper = function(venv_python, env_type)
            log.debug("basedpyright settings_wrapper called with: " .. (venv_python or "nil") .. ", env_type: " .. (env_type or "nil"))
            if not venv_python then
                return { 
                    python = { pythonPath = vim.NIL, venv = vim.NIL, venvPath = vim.NIL },
                    cmd_env = {}
                }
            end
            local venv_path = vim.fn.fnamemodify(venv_python, ":h:h")
            local settings = { 
                python = { 
                    pythonPath = venv_python,
                    venv = vim.fn.fnamemodify(venv_path, ":t"),
                    venvPath = venv_path
                },
                cmd_env = {}  -- No environment variables for basedpyright
            }
            log.debug("basedpyright: Not setting VIRTUAL_ENV or CONDA_PREFIX (relies on settings only)")
            return settings
        end
    },
    pyright = { settings_wrapper = generic_python_settings_wrapper },
    jedi_language_server = { settings_wrapper = generic_python_settings_wrapper },
    ruff = { settings_wrapper = generic_python_settings_wrapper },
    ty = { settings_wrapper = generic_python_settings_wrapper },
    pyrefly = {
        settings_wrapper = function(venv_python, env_type)
            log.debug("pyrefly settings_wrapper called with: " .. (venv_python or "nil") .. ", env_type: " .. (env_type or "nil"))
            if not venv_python then
                return { 
                    python = { pythonPath = vim.NIL, venv = vim.NIL, venvPath = vim.NIL },
                    cmd_env = {}
                }
            end
            local venv_path = vim.fn.fnamemodify(venv_python, ":h:h")
            local settings = { 
                python = { 
                    pythonPath = venv_python,
                    venv = vim.fn.fnamemodify(venv_path, ":t"),
                    venvPath = venv_path
                },
                cmd_env = {}  -- No environment variables for pyrefly
            }
            log.debug("pyrefly: Not setting VIRTUAL_ENV or CONDA_PREFIX (relies on settings only)")
            return settings
        end
    },
    pylsp = {
        settings_wrapper = function(venv_python, env_type)
            local config = {
                pylsp = {
                    plugins = {
                        jedi = {
                            environment = venv_python or vim.NIL,
                        },
                    },
                },
            }
            if venv_python then
                local venv_path = vim.fn.fnamemodify(venv_python, ":h:h")
                config.cmd_env = {}
                -- Set appropriate environment variable based on environment type
                if env_type == "anaconda" then
                    config.cmd_env.CONDA_PREFIX = venv_path
                    config.cmd_env.VIRTUAL_ENV = ""  -- Clear VIRTUAL_ENV for conda
                else
                    config.cmd_env.VIRTUAL_ENV = venv_path
                    config.cmd_env.CONDA_PREFIX = ""  -- Clear CONDA_PREFIX for regular venv
                end
            else
                config.cmd_env = {}
            end
            return config
        end
    },
}

-- Dynamic fallback hook for unknown Python LSPs
function M.dynamic_python_lsp_hook(venv_python, env_type)
    local count = 0
    local known_clients = vim.tbl_keys(LSP_CONFIGS)

    log.debug("dynamic_python_lsp_hook called with venv_python: " ..
    (venv_python or "nil") .. ", env_type: " .. (env_type or "nil"))

    -- Get all currently running clients and check if they're Python LSPs
    local all_clients = vim.lsp.get_clients()
    log.debug("Found " .. #all_clients .. " total LSP clients running")

    for _, client in pairs(all_clients) do
        log.debug("Checking client: " .. client.name .. " (known clients: " .. table.concat(known_clients, ", ") .. ")")
        -- Skip clients that already have explicit hooks
        if not vim.tbl_contains(known_clients, client.name) then
            -- Check if this is a Python LSP by examining filetypes
            local filetypes = vim.tbl_get(client, "config", "filetypes") or {}
            local is_python_lsp = type(filetypes) == "table" and vim.tbl_contains(filetypes, "python")

            log.debug("Client " .. client.name .. " is Python LSP: " .. tostring(is_python_lsp))
            if is_python_lsp then
                -- Only configure if settings changed
                if M.activated_configs[client.name] ~= venv_python then
                    -- Configure with default python settings including venv info
                    local new_config = generic_python_settings_wrapper(venv_python, env_type)

                    -- Update config and restart client  
                    vim.lsp.config(client.name, {
                        settings = new_config.python and { python = new_config.python } or new_config,
                        cmd_env = new_config.cmd_env or {}
                    })
                    
                    -- Use the standard restart mechanism
                    M.restart_lsp_client(client.name, client.id)

                    M.activated_configs[client.name] = venv_python
                    log.debug("Configured unknown Python LSP client " ..
                    client.name .. " with venv: " .. (venv_python or "nil"))
                end
                count = count + 1 -- Always count Python LSPs, even if already configured
            end
        else
            log.debug("Skipping known client: " .. client.name)
        end
    end

    log.debug("dynamic_python_lsp_hook returning count: " .. count)
    return count
end

function M.send_notification(message)
    local now = vim.loop.hrtime()

    -- Check if this is the first notification or if more than 1 second has passed
    local last_notification_time = M.notifications_memory[message]
    if last_notification_time == nil or (now - last_notification_time) > 1e9 then
        log.debug("Below message sent to user since this message was not notified about before.")
        log.info(message)
        vim.notify(message, vim.log.levels.INFO, { title = "VenvSelect" })
        M.notifications_memory[message] = now
    else
        -- Less than one second since last notification with same message
        log.debug("Below message was NOT sent to user since we notified about the same message less than a second ago.")
        log.debug(message)
    end
end

function M.configure_lsp_client(client_name, venv_python, env_type)
    log.debug("configure_lsp_client called for: " ..
    client_name .. " with venv: " .. (venv_python or "nil") .. ", env_type: " .. (env_type or "nil"))
    local lsp_config = LSP_CONFIGS[client_name]
    if not lsp_config then
        log.debug("No specific configuration found for LSP client: " ..
            client_name .. ". Using default python configuration.")
        -- Default fallback configuration for unknown Python LSPs
        lsp_config = { settings_wrapper = generic_python_settings_wrapper }
    end

    -- Only configure if there are running clients for this LSP
    local running_clients = vim.lsp.get_clients({ name = client_name })
    if #running_clients == 0 then
        log.debug("No running clients found for " .. client_name .. ", skipping configuration")
        return 0 -- Return 0 when no clients to configure
    end
    log.debug("Found " .. #running_clients .. " running clients for " .. client_name .. ", proceeding with configuration")

    -- Check if this client is already configured with this venv
    if M.activated_configs[client_name] == venv_python then
        log.debug("Client " ..
            client_name .. " already configured with venv: " .. (venv_python or "nil") .. ". Skipping configuration.")
        return 1 -- Return 1 to indicate this LSP is properly configured
    end

    local config = require("venv-selector.config")
    local new_config = lsp_config.settings_wrapper(venv_python, env_type)

    -- Update the LSP configuration and restart the client
    local lsp_config_update = {}
    if new_config.python then
        lsp_config_update.settings = { python = new_config.python }
    elseif new_config.pylsp then
        lsp_config_update.settings = { pylsp = new_config.pylsp }
    else
        lsp_config_update.settings = new_config
    end
    lsp_config_update.cmd_env = new_config.cmd_env or {}

    log.debug("Updating LSP config for " .. client_name .. " with:", lsp_config_update)
    vim.lsp.config(client_name, lsp_config_update)



    -- Get current clients to track restart
    for _, client in pairs(running_clients) do
        log.debug("Stopping client " .. client_name .. " (id: " .. client.id .. ") before restart")
    end

    -- Restart all running clients for this LSP
    for _, client in pairs(running_clients) do
        M.restart_lsp_client(client_name, client.id)
    end

    -- Track this configuration
    M.activated_configs[client_name] = venv_python
    log.debug("Configured client " .. client_name .. " with venv: " .. (venv_python or "nil"))

    local message
    if venv_python then
        message = "Registered '" .. venv_python .. "' with " .. client_name .. " LSP."
    else
        message = "Cleared Python path from " .. client_name .. " LSP."
    end

    if config.user_settings.options.notify_user_on_venv_activation == true then
        M.send_notification(message)
    end

    return 1
end

-- Generic hook function that works for all supported LSPs
function M.create_hook(client_name)
    return function(venv_python, env_type)
        return M.configure_lsp_client(client_name, venv_python, env_type)
    end
end

-- Specific hook functions for backward compatibility
function M.basedpyright_hook(venv_python, env_type)
    log.debug("basedpyright_hook called with venv_python: " ..
    (venv_python or "nil") .. ", env_type: " .. (env_type or "nil"))
    local result = M.configure_lsp_client("basedpyright", venv_python, env_type)
    log.debug("basedpyright_hook returning: " .. result)
    return result
end

function M.pyright_hook(venv_python, env_type)
    log.debug("pyright_hook called with venv_python: " .. (venv_python or "nil") .. ", env_type: " .. (env_type or "nil"))
    local result = M.configure_lsp_client("pyright", venv_python, env_type)
    log.debug("pyright_hook returning: " .. result)
    return result
end

function M.jedi_language_server_hook(venv_python, env_type)
    log.debug("jedi_language_server_hook called with venv_python: " ..
    (venv_python or "nil") .. ", env_type: " .. (env_type or "nil"))
    local result = M.configure_lsp_client("jedi_language_server", venv_python, env_type)
    log.debug("jedi_language_server_hook returning: " .. result)
    return result
end

function M.ruff_hook(venv_python, env_type)
    log.debug("ruff_hook called with venv_python: " .. (venv_python or "nil") .. ", env_type: " .. (env_type or "nil"))
    local result = M.configure_lsp_client("ruff", venv_python, env_type)
    log.debug("ruff_hook returning: " .. result)
    return result
end

function M.pylsp_hook(venv_python, env_type)
    log.debug("pylsp_hook called with venv_python: " .. (venv_python or "nil") .. ", env_type: " .. (env_type or "nil"))
    local result = M.configure_lsp_client("pylsp", venv_python, env_type)
    log.debug("pylsp_hook returning: " .. result)
    return result
end

function M.ty_hook(venv_python, env_type)
    log.debug("ty_hook called with venv_python: " .. (venv_python or "nil") .. ", env_type: " .. (env_type or "nil"))
    local result = M.configure_lsp_client("ty", venv_python, env_type)
    log.debug("ty_hook returning: " .. result)
    return result
end

function M.pyrefly_hook(venv_python, env_type)
    log.debug("pyrefly_hook called with venv_python: " .. (venv_python or "nil") .. ", env_type: " .. (env_type or "nil"))
    local result = M.configure_lsp_client("pyrefly", venv_python, env_type)
    log.debug("pyrefly_hook returning: " .. result)
    return result
end

-- Add support for new LSPs easily
function M.add_lsp_support(client_name, settings_wrapper, options)
    LSP_CONFIGS[client_name] = vim.tbl_deep_extend("force", {
        settings_wrapper = settings_wrapper,
    }, options or {})
end

-- Unified client restart function
function M.restart_lsp_client(client_name, client_id)
    log.debug("Restarting LSP client: " .. client_name .. " (id: " .. client_id .. ")")
    
    -- First, stop the specific client
    vim.lsp.stop_client(client_id, true)  -- force stop immediately
    
    -- Wait for client to be fully stopped, then restart
    vim.defer_fn(function()
        -- Check if this specific client is gone
        local check_client = vim.lsp.get_client_by_id(client_id)
        if check_client and not check_client:is_stopped() then
            log.debug("Client " .. client_id .. " still running, force stopping again")
            check_client:stop(true)
        end
        
        -- Stop any other clients with the same name to avoid duplicates
        local remaining_clients = vim.lsp.get_clients({ name = client_name })
        for _, remaining in pairs(remaining_clients) do
            if remaining.id ~= client_id then
                log.debug("Stopping duplicate client " .. client_name .. " (id: " .. remaining.id .. ")")
                vim.lsp.stop_client(remaining.id, true)
            end
        end
        
        -- Start fresh client
        vim.defer_fn(function()
            log.debug("Starting fresh client: " .. client_name)
            vim.lsp.enable(client_name, true)
        end, 200)
    end, 300)
end

-- Helper function to clear LSP workspace state and force a clean restart
function M.clear_lsp_workspace(client_name)
    local clients = vim.lsp.get_clients({ name = client_name })
    for _, client in pairs(clients) do
        -- Clear any cached workspace state
        if client.workspace_folders then
            for _, folder in pairs(client.workspace_folders) do
                client:notify("workspace/didChangeWorkspaceFolders", {
                    event = {
                        removed = { folder },
                        added = {}
                    }
                })
            end
        end
        
        -- Send shutdown request
        client:request("shutdown", nil, function()
            client:notify("exit")
        end)
        
        -- Force stop after a brief delay if still running
        vim.defer_fn(function()
            if not client:is_stopped() then
                client:stop(true)
            end
        end, 100)
    end
end

return M
