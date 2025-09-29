local log = require("venv-selector.logger")

local M = {}

M.notifications_memory = {}

-- Track which LSP configs have been activated to prevent redundant operations
-- Format: { lsp_name = venv_python_path }
M.activated_configs = {}

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


-- Unified LSP configuration handler that works both for immediate activation and LspAttach events
local function configure_python_lsp(client, venv_python, env_type)
    -- Since LSP_CONFIGS is empty (all commented out), all Python LSPs use dynamic configuration
    -- No need to check for explicit hooks since none are defined

    -- Check if this is a Python LSP
    local filetypes = vim.tbl_get(client, "config", "filetypes") or {}

    -- Ensure filetypes is a table before calling vim.tbl_contains
    if type(filetypes) ~= "table" then
        return false
    end

    local is_python_lsp = vim.tbl_contains(filetypes, "python")

    if not is_python_lsp then return false end

    -- Handle deactivation when venv_python is nil
    if venv_python == nil then
        vim.lsp.enable(client.name, false)
        M.activated_configs[client.name] = nil
        log.debug("Deactivated lsp for " .. client.name)
        return true
    end

    -- Only configure if settings changed
    if M.activated_configs[client.name] ~= venv_python then
        local new_config = default_lsp_settings(client.name, venv_python, env_type)

        log.debug("Configuring " .. client.name .. " with venv: " .. venv_python)
        vim.lsp.config(client.name, new_config)
        M.restart_lsp_client(client.name, client.id)

        M.activated_configs[client.name] = venv_python
    end

    return true
end

-- Unified LspAttach handler that handles both automatic activation and post-restart configuration
local function setup_unified_lsp_attach()
    local group = vim.api.nvim_create_augroup("VenvSelectorUnified", { clear = true })

    vim.api.nvim_create_autocmd("LspAttach", {
        group = group,
        callback = function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            if not client then return end

            -- Handle automatic activation (like init.lua but integrated)
            if vim.bo.filetype == "python" then
                local cache = require("venv-selector.cached_venv")
                if require("venv-selector.config").user_settings.options.cached_venv_automatic_activation then
                    cache.retrieve() -- This will call our hook which sets current venv info
                end
            end

            -- Get current venv info - either from recent activation or existing state
            local venv_selector = require("venv-selector")
            local current_python = venv_selector.python()
            if current_python and current_python ~= "" then
                -- Determine env type from the python path
                local env_type = "venv" -- default
                if string.find(current_python, "conda") or string.find(current_python, "anaconda") then
                    env_type = "anaconda"
                end

                configure_python_lsp(client, current_python, env_type)
            end
        end
    })
end

-- Simplified dynamic hook that just processes currently running clients
function M.dynamic_python_lsp_hook(venv_python, env_type)
    local count = 0
    local all_clients = vim.lsp.get_clients()

    for _, client in pairs(all_clients) do
        if configure_python_lsp(client, venv_python, env_type) then
            count = count + 1
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

function M.configure_lsp_client(client_name, venv_python, env_type)
    -- Since LSP_CONFIGS is empty, always use default configuration
    log.debug("Using default LSP configuration for: " .. client_name)
    local lsp_config = { settings_wrapper = default_lsp_settings }

    -- Get running clients (common logic should have already validated this)
    local running_clients = vim.lsp.get_clients({ name = client_name })

    local new_config = lsp_config.settings_wrapper(client_name, venv_python, env_type)

    log.debug("Updating LSP config for " .. client_name .. " with:", new_config)
    vim.lsp.config(client_name, new_config)

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

    local config = require("venv-selector.config")
    if config.user_settings.options.notify_user_on_venv_activation == true then
        M.send_notification(message)
    end

    return 1
end

function M.actual_hook(lspserver_name, venv_python, env_type)
    local running_clients = vim.lsp.get_clients({ name = lspserver_name })
    if #running_clients == 0 then
        return 0
    end

    -- Check if this client is already configured with this venv
    if M.activated_configs[lspserver_name] == venv_python then
        log.debug("Client " ..
            lspserver_name .. " already configured with venv: " .. (venv_python or "nil") .. ". Counting as success.")
        return 1 -- Count as success since the LSP is running with correct venv
    end

    return M.configure_lsp_client(lspserver_name, venv_python, env_type)
end

-- Example custom hook (basedpyright works with default hook so its just an example)
function M.basedpyright(venv_python, env_type)
    return M.actual_hook("basedpyright", venv_python, env_type)
end

-- Unified client restart function
function M.restart_lsp_client(client_name, client_id)
    log.debug("Restarting LSP client: " .. client_name .. " (id: " .. client_id .. ")")

    -- First, stop the specific client
    vim.lsp.stop_client(client_id, true) -- force stop immediately

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
            -- log.debug("Starting new client: " .. client_name)
            vim.lsp.enable(client_name, true)
        end, 200)
    end, 300)
end

-- Initialize the unified LspAttach handler when the module is loaded
setup_unified_lsp_attach()

return M
