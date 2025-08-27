local log = require("venv-selector.logger")

---@alias venv-selector.Hook fun(venv_python: string): nil

local M = {}

M.notifications_memory = {}

-- Track configured LSP client + venv combinations to prevent redundant configurations
-- Format: { client_id = venv_python_path }
M.configured_clients = {}

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

function M.set_python_path_for_client(client_name, venv_python)
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
        if client.settings then
            client.settings = vim.tbl_deep_extend("force", client.settings, {
                python = {
                    pythonPath = venv_python,
                },
            })
        else
            client.config.settings = vim.tbl_deep_extend("force", client.config.settings, {
                python = {
                    pythonPath = venv_python,
                },
            })
        end
        client:notify("workspace/didChangeConfiguration", { settings = nil })

        -- Track this configuration
        M.configured_clients[client.id] = venv_python
        log.debug("Configured client " .. client_name .. " (id: " .. client.id .. ") with venv: " .. venv_python)

        local message = "Registered '" .. venv_python .. "' with " .. client_name .. " LSP."
        if config.user_settings.options.notify_user_on_venv_activation == true then
            M.send_notification(message)
        end
    end)
end

function M.basedpyright_hook(venv_python)
    return M.set_python_path_for_client("basedpyright", venv_python)
end

function M.pyright_hook(venv_python)
    return M.set_python_path_for_client("pyright", venv_python)
end

function M.pylance_hook(venv_python)
    return M.set_python_path_for_client("pylance", venv_python)
end

function M.pylsp_hook(venv_python)
    local client_name = "pylsp"
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
        local settings = vim.tbl_deep_extend("force", (client.settings or client.config.settings), {
            pylsp = {
                plugins = {
                    jedi = {
                        environment = venv_python,
                    },
                },
            },
        })
        client:notify("workspace/didChangeConfiguration", { settings = settings })

        -- Track this configuration
        M.configured_clients[client.id] = venv_python
        log.debug("Configured client " .. client_name .. " (id: " .. client.id .. ") with venv: " .. venv_python)

        local message = "Registered '" .. venv_python .. "' with " .. client_name .. " LSP."
        if config.user_settings.options.notify_user_on_venv_activation == true then
            vim.notify(message, vim.log.levels.INFO, {
                title = "VenvSelect",
            })
        end
        log.info(message)
    end)
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
