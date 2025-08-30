local log = require("venv-selector.logger")

---@alias venv-selector.Hook fun(venv_python: string): nil

--[[
Example: Custom hook with custom settings format

function my_custom_lsp_hook(venv_python)
  -- Get the LSP client
  local client = vim.lsp.get_clients({name = "my_custom_lsp"})[1]
  if not client then return 0 end
  
  if venv_python == nil then
    -- Deactivation: stop the client
    vim.lsp.stop_client(client.id)
    return 1
  end
  
  -- Configure with custom settings structure
  client.settings = vim.tbl_deep_extend("force", client.settings or {}, {
    customLsp = {
      pythonExecutable = venv_python,
      workspaceFolder = vim.fn.fnamemodify(venv_python, ":h:h"),
      enableFeatures = true,
    }
  })
  
  -- Notify the LSP of changes
  client:notify("workspace/didChangeConfiguration", { settings = nil })
  
  print("Configured my_custom_lsp with: " .. venv_python)
  return 1  -- Return number of clients configured
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

-- Track configured LSP client + venv combinations to prevent redundant configurations
-- Format: { client_id = venv_python_path }
M.configured_clients = {}

-- Dynamic fallback hook for unknown Python LSPs
function M.dynamic_python_lsp_hook(venv_python)
    local count = 0
    local known_clients = { "basedpyright", "pyright", "jedi_language_server", "pylsp", "ruff" }

    for _, client in pairs(vim.lsp.get_clients()) do
        -- Skip clients that already have explicit hooks
        if not vim.tbl_contains(known_clients, client.name) then
            if client.config and client.config.filetypes and vim.tbl_contains(client.config.filetypes, "python") then
                count = count + M.configure_lsp_client(client.name, venv_python)
            end
        end
    end
    return count
end

-- LSP-specific configuration for different Python language servers
local LSP_CONFIGS = {
    basedpyright = {
        settings_path = { "python", "pythonPath" },
        settings_wrapper = function(venv_python)
            return { python = { pythonPath = venv_python } }
        end
    },
    pyright = {
        settings_path = { "python", "pythonPath" },
        settings_wrapper = function(venv_python)
            return { python = { pythonPath = venv_python } }
        end
    },
    jedi_language_server = {
        settings_path = { "python", "pythonPath" },
        settings_wrapper = function(venv_python)
            return { python = { pythonPath = venv_python } }
        end,
        skip_notify = true -- jedi-language-server doesn't handle didChangeConfiguration well
    },
    ruff = {
        settings_wrapper = function(venv_python)
            return { python = { pythonPath = venv_python } }
        end,
        skip_notify = true -- ruff LSP doesn't handle didChangeConfiguration properly
    },
    pylsp = {
        settings_path = { "pylsp", "plugins", "jedi", "environment" },
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
        end,
        use_settings_directly = true -- pylsp needs settings passed directly to notify
    }
}

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
        log.debug("No specific configuration found for LSP client: " .. client_name .. ". Using default python.pythonPath configuration.")
        -- Default fallback configuration for unknown Python LSPs
        lsp_config = {
            settings_wrapper = function(venv_python)
                return { python = { pythonPath = venv_python } }
            end
        }
    end

    return M.execute_for_client(client_name, function(client)
        if venv_python == nil then
            vim.lsp.stop_client(client.id)
            log.debug("Stopped lsp server for " .. client_name)
            -- Clean up tracking when client is stopped
            M.configured_clients[client.id] = nil
            return
        end

        -- Check if this client is already configured with this venv
        if M.configured_clients[client.id] == venv_python then
            log.debug("Client " .. client_name .. " already configured with venv: " .. venv_python .. ". Skipping configuration.")
            return
        end

        local config = require("venv-selector.config")
        local new_settings = lsp_config.settings_wrapper(venv_python)
        
        -- Update client settings
        if client.settings then
            client.settings = vim.tbl_deep_extend("force", client.settings, new_settings)
        else
            client.config.settings = vim.tbl_deep_extend("force", client.config.settings or {}, new_settings)
        end

        -- Notify client of configuration change (skip for problematic clients)
        if not lsp_config.skip_notify then
            local notify_settings = lsp_config.use_settings_directly and new_settings or nil
            client:notify("workspace/didChangeConfiguration", { settings = notify_settings })
        end

        -- Track this configuration
        M.configured_clients[client.id] = venv_python
        log.debug("Configured client " .. client_name .. " (id: " .. client.id .. ") with venv: " .. venv_python)

        local message = "Registered '" .. venv_python .. "' with " .. client_name .. " LSP."
        if config.user_settings.options.notify_user_on_venv_activation == true then
            M.send_notification(message)
        end
    end)
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

-- Add support for new LSPs easily
function M.add_lsp_support(client_name, settings_wrapper, options)
    LSP_CONFIGS[client_name] = vim.tbl_deep_extend("force", {
        settings_wrapper = settings_wrapper,
        use_settings_directly = false
    }, options or {})
end

function M.execute_for_client(name, callback)
    -- get_active_clients deprecated in neovim v0.10
    local client = vim.lsp.get_clients({ name = name })[1]

    if not client then
        --print('No client named: ' .. name .. ' found')
        return 0
    else
        callback(client)
        return 1
    end
end

-- Clean up tracking data when LSP clients detach
local function setup_client_cleanup()
    vim.api.nvim_create_autocmd("LspDetach", {
        group = vim.api.nvim_create_augroup("VenvSelectorHooks", { clear = true }),
        callback = function(args)
            local client_id = args.data.client_id
            if M.configured_clients[client_id] then
                log.debug("Cleaning up configuration tracking for detached client: " .. client_id)
                M.configured_clients[client_id] = nil
            end
        end,
    })
end

-- Initialize cleanup autocmd
setup_client_cleanup()

return M