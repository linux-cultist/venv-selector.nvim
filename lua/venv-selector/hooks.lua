local log = require("venv-selector.logger")

---@alias venv-selector.Hook fun(venv_python: string): nil

--[[
Example: Custom hook with custom settings format

function my_custom_lsp_hook(venv_python)
  -- Only configure if the LSP is already enabled by the user
  if not vim.lsp.is_enabled('my_custom_lsp') then
    return 0
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

-- LSP-specific configuration for different Python language servers
local LSP_CONFIGS = {
    basedpyright = {
        settings_wrapper = function(venv_python)
            if not venv_python then
                return { python = { pythonPath = vim.NIL, venv = vim.NIL, venvPath = vim.NIL } }
            end
            local venv_path = vim.fn.fnamemodify(venv_python, ":h:h")
            return { 
                python = { 
                    pythonPath = venv_python,
                    venv = vim.fn.fnamemodify(venv_path, ":t"),
                    venvPath = venv_path
                } 
            }
        end
    },
    pyright = {
        settings_wrapper = function(venv_python)
            if not venv_python then
                return { python = { pythonPath = vim.NIL, venv = vim.NIL, venvPath = vim.NIL } }
            end
            local venv_path = vim.fn.fnamemodify(venv_python, ":h:h")
            return { 
                python = { 
                    pythonPath = venv_python,
                    venv = vim.fn.fnamemodify(venv_path, ":t"),
                    venvPath = venv_path
                } 
            }
        end
    },
    jedi_language_server = {
        settings_wrapper = function(venv_python)
            return { python = { pythonPath = venv_python } }
        end
    },
    ruff = {
        settings_wrapper = function(venv_python)
            return { python = { pythonPath = venv_python } }
        end
    },
    pylsp = {
        settings_wrapper = function(venv_python)
            return {
                pylsp = {
                    plugins = {
                        jedi = {
                            environment = venv_python,
                        },
                    },
                },
            }
        end
    },
    ty = {
        settings_wrapper = function(venv_python)
            if not venv_python then
                return { python = { pythonPath = vim.NIL, venv = vim.NIL, venvPath = vim.NIL } }
            end
            local venv_path = vim.fn.fnamemodify(venv_python, ":h:h")
            return { 
                python = { 
                    pythonPath = venv_python,
                    venv = vim.fn.fnamemodify(venv_path, ":t"),
                    venvPath = venv_path
                } 
            }
        end
    },
}

-- Dynamic fallback hook for unknown Python LSPs
function M.dynamic_python_lsp_hook(venv_python)
    local count = 0
    local known_clients = vim.tbl_keys(LSP_CONFIGS)

    -- Get all currently running clients and check if they're Python LSPs
    for _, client in pairs(vim.lsp.get_clients()) do
        -- Skip clients that already have explicit hooks
        if not vim.tbl_contains(known_clients, client.name) then
            -- Check if this is a Python LSP by examining filetypes
            local filetypes = vim.tbl_get(client, "config", "filetypes") or {}
            local is_python_lsp = type(filetypes) == "table" and vim.tbl_contains(filetypes, "python")
            
            if is_python_lsp then
                -- Only configure if settings changed
                if M.activated_configs[client.name] ~= venv_python then
                    -- Configure with default python settings including venv info
                    local new_settings
                    if not venv_python then
                        new_settings = { python = { pythonPath = vim.NIL, venv = vim.NIL, venvPath = vim.NIL } }
                    else
                        local venv_path = vim.fn.fnamemodify(venv_python, ":h:h")
                        new_settings = { 
                            python = { 
                                pythonPath = venv_python,
                                venv = vim.fn.fnamemodify(venv_path, ":t"),
                                venvPath = venv_path
                            } 
                        }
                    end
                    
                    -- Update config and restart client
                    vim.lsp.config(client.name, { settings = new_settings })
                    log.debug("Stopping unknown Python LSP client " .. client.name .. " (id: " .. client.id .. ") before restart")
                    vim.lsp.enable(client.name, false)
                    
                    -- Wait for client to fully stop before restarting
                    vim.defer_fn(function()
                        local remaining_clients = vim.lsp.get_clients({ name = client.name })
                        if #remaining_clients > 0 then
                            -- Force stop any remaining clients
                            for _, remaining_client in pairs(remaining_clients) do
                                vim.lsp.stop_client(remaining_client.id, true)
                            end
                            vim.defer_fn(function()
                                vim.lsp.enable(client.name, true)
                            end, 100)
                        else
                            vim.lsp.enable(client.name, true)
                        end
                    end, 500)
                    
                    M.activated_configs[client.name] = venv_python
                    log.debug("Configured unknown Python LSP client " .. client.name .. " with venv: " .. (venv_python or "nil"))
                    count = count + 1
                end
            end
        end
    end
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

function M.configure_lsp_client(client_name, venv_python)
    local lsp_config = LSP_CONFIGS[client_name]
    if not lsp_config then
        log.debug("No specific configuration found for LSP client: " ..
            client_name .. ". Using default python.pythonPath configuration.")
        -- Default fallback configuration for unknown Python LSPs
        lsp_config = {
            settings_wrapper = function(venv_python)
                return { python = { pythonPath = venv_python } }
            end
        }
    end

    -- Only configure if the LSP is user-enabled
    if not vim.lsp.is_enabled(client_name) then
        return 0
    end

    -- Check if this client is already configured with this venv
    if M.activated_configs[client_name] == venv_python then
        log.debug("Client " ..
            client_name .. " already configured with venv: " .. (venv_python or "nil") .. ". Skipping configuration.")
        return 0
    end

    local config = require("venv-selector.config")
    local new_settings = lsp_config.settings_wrapper(venv_python)

    -- Update the LSP configuration and restart the client
    vim.lsp.config(client_name, { settings = new_settings })
    
    -- Get current clients to track restart
    local current_clients = vim.lsp.get_clients({ name = client_name })
    for _, client in pairs(current_clients) do
        log.debug("Stopping client " .. client_name .. " (id: " .. client.id .. ") before restart")
    end
    
    -- Clear workspace state and properly shutdown
    M.clear_lsp_workspace(client_name)
    
    -- Disable the client
    vim.lsp.enable(client_name, false)
    
    -- Wait longer and ensure all clients are actually stopped before restart
    vim.defer_fn(function()
        local remaining_clients = vim.lsp.get_clients({ name = client_name })
        if #remaining_clients > 0 then
            log.debug("Warning: " .. #remaining_clients .. " clients still running for " .. client_name .. ", force stopping")
            -- Force stop any remaining clients
            for _, client in pairs(remaining_clients) do
                vim.lsp.stop_client(client.id, true)  -- force stop
                log.debug("Force stopped client " .. client_name .. " (id: " .. client.id .. ")")
            end
        end
        
        -- Wait additional time after any force stops, then restart
        vim.defer_fn(function()
            log.debug("Starting fresh client " .. client_name .. " with new Python environment")
            vim.lsp.enable(client_name, true)
            
            -- Verify the restart
            vim.defer_fn(function()
                local new_clients = vim.lsp.get_clients({ name = client_name })
                for _, client in pairs(new_clients) do
                    log.debug("New client started: " .. client_name .. " (id: " .. client.id .. ")")
                end
            end, 1000)
        end, 1000)  -- Wait 1 second for clean restart
    end, 500)

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
    return function(venv_python)
        return M.configure_lsp_client(client_name, venv_python)
    end
end

-- Specific hook functions for backward compatibility
function M.basedpyright_hook(venv_python)
    return M.configure_lsp_client("basedpyright", venv_python)
end

function M.pyright_hook(venv_python)
    return M.configure_lsp_client("pyright", venv_python)
end

function M.jedi_language_server_hook(venv_python)
    return M.configure_lsp_client("jedi_language_server", venv_python)
end

function M.ruff_hook(venv_python)
    return M.configure_lsp_client("ruff", venv_python)
end

function M.pylsp_hook(venv_python)
    return M.configure_lsp_client("pylsp", venv_python)
end

function M.ty_hook(venv_python)
    return M.configure_lsp_client("ty", venv_python)
end

-- Add support for new LSPs easily
function M.add_lsp_support(client_name, settings_wrapper, options)
    LSP_CONFIGS[client_name] = vim.tbl_deep_extend("force", {
        settings_wrapper = settings_wrapper,
    }, options or {})
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