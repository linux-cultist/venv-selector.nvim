local log = require("venv-selector.logger")
local gate = require("venv-selector.lsp_gate")

local M = {}

M.notifications_memory = {}

vim.g.venv_selector_pending_lsp_apply = true


---Create environment variables for the LSP client command
---@param client_name string The name of the LSP client
---@param venv_python string|nil The path to the python executable
---@param env_type string|nil The type of the virtual environment
---@return table env A table containing the cmd_env configuration
local function create_cmd_env(client_name, venv_python, env_type)
    if venv_python == nil then return { cmd_env = {} } end
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


---Generate default LSP settings and environment for a venv
---@param client_name string The name of the LSP client
---@param venv_python string|nil The path to the python executable
---@param env_type string|nil The type of the virtual environment
---@return table client_config The configuration structure for the LSP client
local function default_lsp_settings(client_name, venv_python, env_type)
    if venv_python == nil then return { settings = {} } end
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




---Restart all active python LSP clients with the new venv configuration
---@param venv_python string|nil The path to the python executable
---@param env_type string|nil The type of the virtual environment
---@return boolean success, string? error Whether any clients were found and restart was attempted
local function restart_all_python_lsps(venv_python, env_type)
    for _, c in ipairs(vim.lsp.get_clients()) do
        local fts = (c.config and c.config.filetypes) and table.concat(c.config.filetypes, ",") or ""
        local root = (c.config and c.config.root_dir) or ""
        log.debug(("lsp seen id=%d name=%s root=%s fts=[%s]"):format(c.id, c.name, root, fts))
    end

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

    local function is_generic_or_multi(client)
      local fts = client.config and client.config.filetypes or nil
      if not fts then return false end
      if vim.tbl_contains(fts, "markdown") or vim.tbl_contains(fts, "text") or vim.tbl_contains(fts, "gitcommit") then
        return true
      end
      -- very broad servers (like harper_ls) should not be restarted by venv changes
      return #fts > 8
    end

    local function loaded_python_bufs()
        local bufs = {} ---@type table<number,true>
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(b)
                and vim.api.nvim_buf_is_valid(b)
                and vim.bo[b].buftype == ""
                and vim.bo[b].filetype == "python"
            then
                bufs[b] = true
            end
        end
        return bufs
    end

    local function is_python_lsp(client)
        local fts = client.config and client.config.filetypes or nil
        return contains(fts, "python") and not is_generic_or_multi(client)
    end

    local pybufs = {}
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(b)
            and vim.api.nvim_buf_is_loaded(b)
            and vim.bo[b].buftype == ""
            and vim.bo[b].filetype == "python"
        then
            pybufs[#pybufs + 1] = b
            log.debug(("pybuf b=%d file=%s"):format(b, vim.api.nvim_buf_get_name(b)))
        end
    end
    log.debug(("pybuf count=%d"):format(#pybufs))

    local by_name = {} ---@type table<string, {client:any, bufs:table<number,true>}>
    local pybufs = loaded_python_bufs()

    for _, c in ipairs(vim.lsp.get_clients()) do
        if is_python_lsp(c) then
            local entry = by_name[c.name]
            if not entry then
                entry = { client = c, bufs = pybufs } -- use global python bufs
                by_name[c.name] = entry
            end
        end
    end

    local names = 0
    for name, entry in pairs(by_name) do
        names = names + 1
        local nbuf = 0
        for _ in pairs(entry.bufs or {}) do nbuf = nbuf + 1 end
        log.debug(("group name=%s bufs=%d"):format(name, nbuf))
    end
    log.debug(("group total=%d"):format(names))

    if next(by_name) == nil then
        log.debug("restart_all_python_lsps: no python LSP clients selected")
        return false, "no python LSP clients selected"
    end

    if venv_python == nil then
        log.debug("restart_all_python_lsps: venv_python=nil, nothing to restart")
        return true
    end

    if next(by_name) == nil then
        return false, "no python LSP clients selected"
    end
    if venv_python == nil then return true end

    for name, entry in pairs(by_name) do
        local old_cfg    = entry.client.config or {}
        local cfg        = vim.deepcopy(old_cfg)

        local gen        = default_lsp_settings(name, venv_python, env_type)
        cfg.settings     = gen.settings
        cfg.cmd_env      = gen.cmd_env

        -- preserve these explicitly (deepcopy may already include them, but keep as you had)
        cfg.capabilities = old_cfg.capabilities
        cfg.handlers     = old_cfg.handlers
        cfg.on_attach    = old_cfg.on_attach
        cfg.init_options = old_cfg.init_options

        gate.request(name, cfg, entry.bufs)
    end

    return true
end




---Dynamic hook that processes currently running clients (called when venv is selected)
---@param venv_python string|nil The path to the python executable
---@param env_type string|nil The type of the virtual environment
---@return integer count The number of hooks that were processed
function M.dynamic_python_lsp_hook(venv_python, env_type)
    log.debug(("hook dynamic_python_lsp_hook venv=%s type=%s"):format(tostring(venv_python), tostring(env_type)))
    local ok = restart_all_python_lsps(venv_python, env_type)
    return ok == true and 1 or 0
end

---Send a notification to the user, throttled to once per second for unique messages
---@param message string The message to notify
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
