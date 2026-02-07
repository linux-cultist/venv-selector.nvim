local log = require("venv-selector.logger")
local gate = require("venv-selector.lsp_gate")

local M = {}
local last_restart_by_root = {} -- project_root -> { py=string, ty=string }


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
local function restart_all_python_lsps(venv_python, env_type, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local project_root = require("venv-selector.project_root").key_for_buf(bufnr) or ""

    if not project_root or project_root == "" then
        local venv = require("venv-selector.venv")
        if venv.active_project_root then
            project_root = venv.active_project_root()
        end
    end


    local py = venv_python or ""
    local ty = env_type or ""

    if project_root == "" then
        log.debug("restart_all_python_lsps: project_root empty; not caching restart decision")
    else
        local last = last_restart_by_root[project_root]
        if last and last.py == py and last.ty == ty then
            log.debug(("restart_all_python_lsps: no-op (unchanged) root=%s py=%s type=%s"):format(project_root, py, ty))
            return true
        end

        last_restart_by_root[project_root] = { py = py, ty = ty }
    end

    for _, c in ipairs(vim.lsp.get_clients()) do
        local fts = (c.config and c.config.filetypes) and table.concat(c.config.filetypes, ",") or ""
        local root = (c.config and c.config.root_dir) or ""
        log.debug(("lsp seen id=%d name=%s root=%s fts=[%s]"):format(c.id, c.name, root, fts))
    end

    local function contains(list, item)
        return list and vim.tbl_contains(list, item)
    end

    local function is_generic_or_multi(client)
        local fts = client.config and client.config.filetypes or nil
        if not fts then return false end
        if vim.tbl_contains(fts, "markdown") or vim.tbl_contains(fts, "text") or vim.tbl_contains(fts, "gitcommit") then
            return true
        end
        return #fts > 8
    end

    local function is_python_lsp(client)
        local fts = client.config and client.config.filetypes or nil
        return contains(fts, "python") and not is_generic_or_multi(client)
    end

    local function attached_python_bufs(client)
        local bufs = {}
        for b, _ in pairs(client.attached_buffers or {}) do
            if vim.api.nvim_buf_is_valid(b) and vim.bo[b].filetype == "python" and vim.bo[b].buftype == "" then
                bufs[b] = true
            end
        end
        return bufs
    end

    local by_key = {} ---@type table<string, {client:any, bufs:table<number,true>, name:string, root:string}>

    for _, c in ipairs(vim.lsp.get_clients()) do
        if is_python_lsp(c) then
            local root = (c.config and c.config.root_dir) or ""
            if project_root == nil or root == project_root then
                local key = c.name .. "::" .. root
                if not by_key[key] then
                    by_key[key] = { client = c, bufs = attached_python_bufs(c), name = c.name, root = root }
                end
            end
        end
    end

    if next(by_key) == nil then
        log.debug("restart_all_python_lsps: no python LSP clients selected for this project_root")
        return false, "no python LSP clients selected for this project_root"
    end

    if venv_python == nil then
        log.debug("restart_all_python_lsps: venv_python=nil, nothing to restart")
        return true
    end

    for key, entry in pairs(by_key) do
        local old_cfg    = entry.client.config or {}
        local cfg        = vim.deepcopy(old_cfg)

        local gen        = default_lsp_settings(entry.name, venv_python, env_type)
        cfg.settings     = gen.settings
        cfg.cmd_env      = gen.cmd_env

        cfg.capabilities = old_cfg.capabilities
        cfg.handlers     = old_cfg.handlers
        cfg.on_attach    = old_cfg.on_attach
        cfg.init_options = old_cfg.init_options

        -- NOTE: gate key is now key (= name::root)
        gate.request(key, cfg, entry.bufs)
    end

    return true
end




---Dynamic hook that processes currently running clients (called when venv is selected)
---@param venv_python string|nil The path to the python executable
---@param env_type string|nil The type of the virtual environment
---@return integer count The number of hooks that were processed
function M.dynamic_python_lsp_hook(venv_python, env_type, bufnr)
    log.debug(("hook dynamic_python_lsp_hook venv=%s type=%s"):format(tostring(venv_python), tostring(env_type)))
    local ok = restart_all_python_lsps(venv_python, env_type, bufnr)
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
