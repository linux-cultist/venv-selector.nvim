local log = require("venv-selector.logger")

local M = {}

M.notifications_memory = {}


local function create_cmd_env(client_name, venv_python, env_type)
    local venv_path = vim.fn.fnamemodify(venv_python, ":h:h")
    local env = {
        cmd_env = {}
    }
    if env_type == "anaconda" then
        env.cmd_env.CONDA_PREFIX = venv_path
        log.debug(client_name .. ": Setting CONDA_PREFIX for conda environment: " .. venv_path)
    elseif env_type == "venv" then
        env.cmd_env.VIRTUAL_ENV = venv_path
        log.debug(client_name .. ": Setting VIRTUAL_ENV for regular environment: " .. venv_path)
    elseif env_type == "uv" then
        env.cmd_env.VIRTUAL_ENV = venv_path
        log.debug(client_name .. ": Setting VIRTUAL_ENV for uv environment: " .. venv_path)
    else
        log.debug(client_name .. "Unknown venv type: " .. env_type)
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
        -- log.debug("Found existing settings for " .. client_name .. ":", existing_settings)
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
    local cmd_env = create_cmd_env(client_name, venv_python, env_type)

    -- Return proper ClientConfig structure
    local client_config = {
        settings = merged_settings,
    }

    -- Add cmd_env to the client config if it has values
    if cmd_env.cmd_env and next(cmd_env.cmd_env) then
        client_config.cmd_env = cmd_env.cmd_env
    end

    -- log.debug("Generated client config for " .. client_name .. ":", client_config)
    return client_config
end




local function restart_all_python_lsps(venv_python, env_type)
    local function contains(list, item)
        return list and vim.tbl_contains(list, item)
    end

    local function has_python_attachment(client)
        for b, _ in pairs(client.attached_buffers or {}) do
            if vim.api.nvim_buf_is_valid(b) and vim.bo[b].filetype == "python" then
                return true
            end
        end
        return false
    end

    local function is_generic_text_server(client)
        local fts = client.config and client.config.filetypes or nil
        if not fts then return false end
        -- Heuristic: skip servers that also target general prose editing
        return contains(fts, "markdown") or contains(fts, "text") or contains(fts, "gitcommit")
    end

    local function is_python_lsp(client)
        local fts = client.config and client.config.filetypes or nil
        return contains(fts, "python")
            and has_python_attachment(client)
            and not is_generic_text_server(client)
    end

    -- Collect python LSP clients grouped by name + buffers
    local by_name = {} ---@type table<string, {client:any, bufs:table<number,true>}>
    for _, c in ipairs(vim.lsp.get_clients()) do
        if is_python_lsp(c) then
            local entry = by_name[c.name]
            if not entry then
                entry = { client = c, bufs = {} }
                by_name[c.name] = entry
            end
            for b, _ in pairs(c.attached_buffers or {}) do
                entry.bufs[b] = true
            end
        end
    end
    if next(by_name) == nil then return false, "no python LSP clients selected" end

    -- Stop all instances for these names (0.11-safe; no deprecated stop_client signature)
    for name, _ in pairs(by_name) do
        for _, c in ipairs(vim.lsp.get_clients({ name = name })) do
            pcall(function() c:stop() end)
        end
    end

    -- Restart each server with your merged settings
    vim.defer_fn(function()
        for name, entry in pairs(by_name) do
            local old_cfg    = entry.client.config or {}
            local cfg        = vim.deepcopy(old_cfg)

            local gen        = default_lsp_settings(name, venv_python, env_type)
            cfg.settings     = gen.settings
            cfg.cmd_env      = gen.cmd_env

            cfg.capabilities = old_cfg.capabilities
            cfg.handlers     = old_cfg.handlers
            cfg.on_attach    = old_cfg.on_attach
            cfg.init_options = old_cfg.init_options

            local first_buf
            for b, _ in pairs(entry.bufs) do
                if vim.api.nvim_buf_is_valid(b) then
                    first_buf = b; break
                end
            end
            if first_buf then
                local new_id = vim.lsp.start(cfg, {
                    bufnr = first_buf,
                    reuse_client = function() return false end,
                })
                if new_id then
                    for b, _ in pairs(entry.bufs) do
                        if b ~= first_buf and vim.api.nvim_buf_is_valid(b) then
                            vim.lsp.buf_attach_client(b, new_id)
                        end
                    end
                end
            end
        end
    end, 250)

    return true
end




-- Dynamic hook that processes currently running clients (called when venv is selected)
function M.dynamic_python_lsp_hook(venv_python, env_type)
    local rc = restart_all_python_lsps(venv_python, env_type)
    if rc == true then return 1 else return 0 end
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

return M
