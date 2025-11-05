local log = require("venv-selector.logger")

local M = {}

M.notifications_memory = {}

-- Track which LSP configs have been activated to prevent redundant operations
-- Format: { lsp_name = venv_python_path }
M.activated_configs = {}

-- Track which clients are currently being restarted to prevent duplicate shutdown requests
local restarting_clients = {}

-- Helper function to determine if an LSP client is primarily a Python LSP
local function is_python_lsp_client(client)
    local filetypes = vim.tbl_get(client, "config", "filetypes") or {}
    
    -- Ensure filetypes is a table before processing
    if type(filetypes) ~= "table" then
        return false
    end
    
    -- Must support Python to be considered
    if not vim.tbl_contains(filetypes, "python") then
        return false
    end
    
    -- If it only supports a few filetypes and python is one of them, likely a Python LSP
    if #filetypes <= 3 and (vim.tbl_contains(filetypes, "python") or vim.tbl_contains(filetypes, "pyi")) then
        return true
    end
    
    -- Check if server name contains python-related terms
    if client.name:match("py") or client.name:match("python") then
        return true
    end
    
    -- Check if the command contains python-related terms
    if client.config.cmd and type(client.config.cmd) == "table" and client.config.cmd[1] then
        local cmd = client.config.cmd[1]:lower()
        if cmd:match("py") or cmd:match("python") then
            return true
        end
    end
    
    return false
end

-- LSP servers that don't work with vim.lsp.enable and need client.stop() instead
local stubborn_lsp_servers = {
    ["jedi_language_server"] = true,
    ["pyrefly"] = true,
    ["zuban"] = true,
}



local function create_cmd_env(venv_python, env_type)
    local venv_path = vim.fn.fnamemodify(venv_python, ":h:h")
    local env = {
        cmd_env = {}
    }
    if env_type == "anaconda" then
        env.cmd_env.CONDA_PREFIX = venv_path
        log.debug("Setting CONDA_PREFIX for conda environment: " .. venv_path)
    elseif env_type == "venv" then
        env.cmd_env.VIRTUAL_ENV = venv_path
        log.debug("Setting VIRTUAL_ENV for regular environment: " .. venv_path)
    else
        log.debug("Unknown venv type: " .. env_type)
    end

    return env
end



local function default_lsp_settings(client_name, venv_python, env_type)
    local venv_dir          = vim.fn.fnamemodify(venv_python, ":h:h")
    local venv_name         = vim.fn.fnamemodify(venv_dir, ":t")
    local venv_path         = vim.fn.fnamemodify(venv_dir, ":h")

    -- Get existing client configuration to preserve user settings
    local existing_clients  = vim.lsp.get_clients({ name = client_name })
    local existing_settings = {}

    if #existing_clients > 0 then
        local client_config = existing_clients[1].config or {}
        existing_settings = vim.deepcopy(client_config.settings or {})
        log.debug("Found existing settings for " .. client_name .. ":", existing_settings)
    end

    -- Create venv-specific settings
    local venv_settings = {
        python = {
            pythonPath = venv_python,
            venv       = venv_name,
            venvPath   = venv_path,
        },
    }

    -- Merge existing user settings with venv settings (venv settings take precedence for python path)
    local merged_settings = vim.tbl_deep_extend("force", existing_settings, venv_settings)

    -- Create cmd_env for the client config
    local cmd_env = create_cmd_env(venv_python, env_type)

    -- Return proper ClientConfig structure
    local client_config = {
        settings = merged_settings,
    }

    -- Add cmd_env to the client config if it has values
    if cmd_env.cmd_env and next(cmd_env.cmd_env) then
        client_config.cmd_env = cmd_env.cmd_env
    end

    log.debug("Generated client config for " .. client_name .. ":", client_config)
    return client_config
end


-- Common hook function to handle shared logic before calling individual hooks
-- Returns: { continue = boolean, result = number }
-- If continue = false, the individual hook should return the result immediately
function M.ok_to_activate(client_name, venv_python)
    local running_clients = vim.lsp.get_clients({ name = client_name })
    if #running_clients == 0 then
        return false
    end
    log.debug("Found " .. #running_clients .. " running clients for " .. client_name .. ", proceeding with configuration")

    -- Check if this client is already configured with this venv
    if M.activated_configs[client_name] == venv_python then
        log.debug("Client " ..
            client_name .. " already configured with venv: " .. (venv_python or "nil") .. ". Skipping configuration.")
        return false
    end

    return true
end

local function configure_python_lsp(client, venv_python, env_type)
    -- Since LSP_CONFIGS is empty (all commented out), all Python LSPs use dynamic configuration
    -- No need to check for explicit hooks since none are defined

    -- Check if this is a Python LSP
    local filetypes = vim.tbl_get(client, "config", "filetypes") or {}

    -- Ensure filetypes is a table before calling vim.tbl_contains
    if type(filetypes) ~= "table" then
        return false
    end

    local is_python_lsp = is_python_lsp_client(client)
    -- log.debug(client.name .. " is python_lsp: " .. tostring(is_python_lsp))

    if not is_python_lsp then return false end

    -- Track this as a Python LSP for log forwarding
    log.track_python_lsp(client.name)

    -- Handle deactivation when venv_python is nil
    if venv_python == nil then
        vim.lsp.enable(client.name, false)
        M.activated_configs[client.name] = nil
        log.debug("Deactivated lsp for " .. client.name)
        return true
    end

    -- Only configure if settings changed
    if M.activated_configs[client.name] ~= venv_python then
        log.debug("Configuring " .. client.name .. " with venv: " .. venv_python)

        -- Only restart if not already restarting
        if not restarting_clients[client.name] then
            M.restart_lsp_client(client.name, client.id, venv_python, env_type)
        else
            log.debug("Client " .. client.name .. " is already restarting, skipping")
        end

        M.activated_configs[client.name] = venv_python
    end

    return true
end

-- Simple function to configure all Python LSP clients with new venv
local function configure_all_python_lsps(venv_python, env_type)
    log.debug("configure_all_python_lsps called with venv_python: " ..
        tostring(venv_python) .. ", env_type: " .. tostring(env_type))
    if not venv_python then
        log.debug("No venv specified, skipping LSP configuration")
        return
    end

    local all_clients = vim.lsp.get_clients()
    local count = 0

    for _, client in pairs(all_clients) do
        if configure_python_lsp(client, venv_python, env_type) then
            count = count + 1
        end
    end

    log.debug("Configured " .. count .. " Python LSP clients with venv: " .. venv_python)
    return count
end

-- Unified LSP configuration that works for both cache activation and picker selection
local function setup_python_filetype_handler()
    local group = vim.api.nvim_create_augroup("VenvSelectorPython", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "python",
        callback = function()
            -- Handle automatic activation from cache
            if require("venv-selector.config").user_settings.options.cached_venv_automatic_activation then
                log.debug("FileType python: attempting cache retrieval")
                local cache = require("venv-selector.cached_venv")
                cache.retrieve() -- This calls venv.activate which calls our hook
                log.debug("FileType python: cache.retrieve() completed")
            end
        end
    })


    -- Handle LspAttach for clients that start after venv is already activated
    vim.api.nvim_create_autocmd("LspAttach", {
        group = group,
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if not client then return end

            -- Only handle Python LSP clients
            if not is_python_lsp_client(client) then
                return
            end



            -- Get current venv info
            local venv_selector = require("venv-selector")
            local current_python = venv_selector.python()
            if current_python and current_python ~= "" then
                -- Only configure if client doesn't already have the right venv
                if M.activated_configs[client.name] ~= current_python then
                    -- Determine env type from the python path
                    local env_type = "venv" -- default
                    if string.find(current_python, "conda") or string.find(current_python, "anaconda") then
                        env_type = "anaconda"
                    end

                    log.debug("LspAttach: configuring " .. client.name .. " with current venv: " .. current_python)
                    configure_python_lsp(client, current_python, env_type)
                end
            end
        end
    })
end

-- Dynamic hook that processes currently running clients (called when venv is selected)
function M.dynamic_python_lsp_hook(venv_python, env_type)
    log.debug("dynamic_python_lsp_hook called with venv_python: " ..
        tostring(venv_python) .. ", env_type: " .. tostring(env_type))
    return configure_all_python_lsps(venv_python, env_type)
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

-- function M.configure_lsp_client(client_name, venv_python, env_type)
--     -- Since LSP_CONFIGS is empty, always use default configuration
--     log.debug("Using default LSP configuration for: " .. client_name)
--     local lsp_config = { settings_wrapper = default_lsp_settings }

--     -- Get running clients (common logic should have already validated this)
--     local running_clients = vim.lsp.get_clients({ name = client_name })

--     local new_config = lsp_config.settings_wrapper(client_name, venv_python, env_type)

--     log.debug("Updating LSP config for " .. client_name .. " with:", new_config)
--     vim.lsp.config(client_name, new_config)


--     -- Restart all running clients for this LSP
--     for _, client in pairs(running_clients) do
--         M.restart_lsp_client(client_name, client.id)
--     end

--     -- Track this configuration
--     M.activated_configs[client_name] = venv_python
--     log.debug("Configured client " .. client_name .. " with venv: " .. (venv_python or "nil"))

--     local message
--     if venv_python then
--         message = "Registered '" .. venv_python .. "' with " .. client_name .. " LSP."
--     else
--         message = "Cleared Python path from " .. client_name .. " LSP."
--     end

--     local config = require("venv-selector.config")
--     if config.user_settings.options.notify_user_on_venv_activation == true then
--         M.send_notification(message)
--     end

--     return 1
-- end

-- function M.actual_hook(lspserver_name, venv_python, env_type)
--     local running_clients = vim.lsp.get_clients({ name = lspserver_name })
--     if #running_clients == 0 then
--         return 0
--     end

--     -- Check if this client is already configured with this venv
--     if M.activated_configs[lspserver_name] == venv_python then
--         log.debug("Client " ..
--             lspserver_name .. " already configured with venv: " .. (venv_python or "nil") .. ". Counting as success.")
--         return 1 -- Count as success since the LSP is running with correct venv
--     end

--     return M.configure_lsp_client(lspserver_name, venv_python, env_type)
-- end

-- Example custom hook (basedpyright works with default hook so its just an example)
-- function M.basedpyright(venv_python, env_type)
--     return M.actual_hook("basedpyright", venv_python, env_type)
-- end

-- Restart function with simple enable/disable and proper waiting
function M.restart_lsp_client(client_name, client_id, venv_python, env_type)
    log.debug("Restarting LSP client: " .. client_name .. " (id: " .. client_id .. ")")

    -- Mark client as restarting to prevent duplicate requests
    restarting_clients[client_name] = true

    -- Temporarily disable diagnostic and other automatic requests
    local client = vim.lsp.get_client_by_id(client_id)
    local use_client_stop = stubborn_lsp_servers[client_name]

    if client then
        -- Disable client capabilities temporarily to prevent requests during shutdown
        client.server_capabilities = client.server_capabilities or {}
        local saved_capabilities = vim.deepcopy(client.server_capabilities)

        -- Disable capabilities that might trigger requests
        client.server_capabilities.textDocumentSync = false
        client.server_capabilities.diagnosticProvider = false
        client.server_capabilities.semanticTokensProvider = false

        -- Store original capabilities for debugging
        client._saved_capabilities = saved_capabilities
    end

    -- Use appropriate shutdown method based on server type
    if use_client_stop and client then
        log.debug("Using client.stop() for stubborn server: " .. client_name)
        pcall(client.stop, client, true)
    else
        log.debug("Using vim.lsp.enable(false) for server: " .. client_name)
        vim.lsp.enable(client_name, false)
    end

    -- Check if the specific client ID is gone
    local function check_client_shutdown(attempts)
        attempts = attempts or 0
        local client = vim.lsp.get_client_by_id(client_id)

        if not client then
            -- Client is gone, safe to restart with new config
            log.debug("Client " .. client_name .. " (id: " .. client_id .. ") has shut down, configuring and restarting")

            -- Configure with new settings before restart
            if venv_python and env_type then
                local new_config = default_lsp_settings(client_name, venv_python, env_type)
                vim.lsp.config(client_name, new_config)
            end

            vim.lsp.enable(client_name, true)
            log.debug("Successfully restarted " .. client_name .. " with new venv configuration")
 
 
            local message
            if venv_python then
                message = "Registered '" .. venv_python .. "' with " .. client_name .. " LSP."
            else
                message = "Cleared Python path from " .. client_name .. " LSP."
            end
           
            local config = require("venv-selector.config")
            if config.user_settings.options.notify_user_on_venv_activation == true then
                M.send_notification(message)
            end

            
            
            -- Clear the restarting flag after restart
            vim.defer_fn(function()
                restarting_clients[client_name] = nil
            end, 1000)
        elseif attempts < 20 then -- Only try 10 times (1 second)
            log.debug("Client " ..
                client_name .. " (id: " .. client_id .. ") still running, attempt " .. (attempts + 1) .. "/10")
            vim.defer_fn(function()
                check_client_shutdown(attempts + 1)
            end, 100)
        else
            -- Client doesn't respond to vim.lsp.enable, skip restart
            log.warning("Client " ..
                client_name ..
                " (id: " ..
                client_id .. ") doesn't respond to vim.lsp.enable, skipping restart - client won't get new venv settings")
            -- Clear the restarting flag and leave the existing client running
            restarting_clients[client_name] = nil
        end
    end

    -- Start checking after initial delay
    vim.defer_fn(function() check_client_shutdown(0) end, 100)
end

-- Unified client restart function
-- function M.restart_lsp_client(client_name, client_id)
--     log.debug("Restarting LSP client: " .. client_name .. " (id: " .. client_id .. ")")

--     -- First, stop the specific client
--     vim.lsp.stop_client(client_id, true) -- force stop immediately

--     -- Wait for client to be fully stopped, then restart
--     vim.defer_fn(function()
--         -- Check if this specific client is gone
--         local check_client = vim.lsp.get_client_by_id(client_id)
--         if check_client and not check_client:is_stopped() then
--             log.debug("Client " .. client_id .. " still running, force stopping again")
--             check_client:stop(true)
--         end

--         -- Stop any other clients with the same name to avoid duplicates
--         local remaining_clients = vim.lsp.get_clients({ name = client_name })
--         for _, remaining in pairs(remaining_clients) do
--             if remaining.id ~= client_id then
--                 log.debug("Stopping duplicate client " .. client_name .. " (id: " .. remaining.id .. ")")
--                 vim.lsp.stop_client(remaining.id, true)
--             end
--         end

--         -- Start fresh client
--         vim.defer_fn(function()
--             -- log.debug("Starting new client: " .. client_name)
--             vim.lsp.enable(client_name, true)
--         end, 200)
--     end, 300)
-- end

-- Initialize the Python FileType handler when the module is loaded
setup_python_filetype_handler()

return M
