-- lua/venv-selector/hooks.lua
--
-- Hook implementations for venv-selector.nvim.
--
-- Responsibilities:
-- - Provide the default “restart python LSP clients” hook used after venv activation.
-- - Generate venv-aware LSP settings/cmd_env (VIRTUAL_ENV / CONDA_PREFIX) while preserving user config.
-- - Select only python-specific LSP clients (avoid generic/multi-language servers).
-- - Coalesce and scope restarts via the LSP restart gate using a stable key: "<client_name>::<root_dir>".
-- - Throttle user notifications to avoid spam (per-message, 1s).
--
-- Design notes:
-- - Restarts are memoized per project_root so identical (python,type) combinations are a no-op.
-- - Buffer reattachment is preserved by collecting attached python buffers before restarting.
-- - Root resolution prefers project_root.key_for_buf(bufnr) and falls back to venv.active_project_root().
--
-- Conventions:
-- - env_type is one of: "venv" | "conda" | "uv".
-- - Returned buffer sets are keyed as: table<integer, true>.

require("venv-selector.types")

local log = require("venv-selector.logger")
local gate = require("venv-selector.lsp_gate")

local M = {}

---@type table<string, venv-selector.RestartMemo>
local last_restart_by_root = {}

---@type table<string, integer>
M.notifications_memory = {}

---@param list any[]|nil
---@param item any
---@return boolean
local function contains(list, item)
    return list ~= nil and vim.tbl_contains(list, item)
end

---Heuristic: treat large or generic/multi-filetype servers as non-python-specific.
---@param client any
---@return boolean
local function is_generic_or_multi(client)
    local fts = client.config and client.config.filetypes or nil
    if not fts then return false end
    if vim.tbl_contains(fts, "markdown") or vim.tbl_contains(fts, "text") or vim.tbl_contains(fts, "gitcommit") then
        return true
    end
    return #fts > 8
end

---True if client is a python-specific LSP (not a generic multi-language server).
---@param client any
---@return boolean
local function is_python_lsp(client)
    local fts = client.config and client.config.filetypes or nil
    return contains(fts, "python") and not is_generic_or_multi(client)
end

---Collect python buffers currently attached to an LSP client.
---Returned set is keyed by bufnr: { [bufnr]=true, ... }
---@param client any
---@return table<integer, true> bufs
local function attached_python_bufs(client)
    ---@type table<integer, true>
    local bufs = {}
    for b, _ in pairs(client.attached_buffers or {}) do
        if vim.api.nvim_buf_is_valid(b) and vim.bo[b].filetype == "python" and vim.bo[b].buftype == "" then
            bufs[b] = true
        end
    end
    return bufs
end

---Create cmd_env for a client restart based on venv type.
---@param client_name string
---@param venv_python string|nil
---@param env_type venv-selector.VenvType|nil
---@return venv-selector.LspCmdEnv env
local function create_cmd_env(client_name, venv_python, env_type)
    if not venv_python or venv_python == "" then
        return { cmd_env = {} }
    end

    local venv_path = vim.fn.fnamemodify(venv_python, ":h:h") -- .../venv
    local env = { cmd_env = {} }

    if env_type == "conda" then
        env.cmd_env.CONDA_PREFIX = venv_path
        log.debug(client_name .. ": Setting CONDA_PREFIX for conda environment: " .. venv_path)
    elseif env_type == "venv" or env_type == "uv" then
        env.cmd_env.VIRTUAL_ENV = venv_path
        log.debug(client_name .. ": Setting VIRTUAL_ENV for environment: " .. venv_path)
    else
        log.debug(client_name .. ": Unknown venv type: " .. tostring(env_type))
    end

    return env
end

---Generate venv-specific LSP settings, preserving existing user settings where possible.
---@param client_name string
---@param venv_python string|nil
---@param env_type venv-selector.VenvType|nil
---@return venv-selector.LspClientConfig cfg
local function default_lsp_settings(client_name, venv_python, env_type)
    if not venv_python or venv_python == "" then
        return { settings = {} }
    end

    local venv_dir          = vim.fn.fnamemodify(venv_python, ":h:h")
    local venv_name         = vim.fn.fnamemodify(venv_dir, ":t")
    local venv_path         = vim.fn.fnamemodify(venv_dir, ":h")

    -- Preserve existing settings for this client if one exists
    local existing_clients  = vim.lsp.get_clients({ name = client_name })
    local existing_settings = {}
    if #existing_clients > 0 then
        local client_config = existing_clients[1].config or {}
        existing_settings = vim.deepcopy(client_config.settings or {})
    end

    local venv_settings = {
        python = {
            pythonPath = venv_python,
            venv = venv_name,
            venvPath = venv_path,
        },
    }

    local merged_settings = vim.tbl_deep_extend("force", existing_settings, venv_settings)
    local cmd_env = create_cmd_env(client_name, venv_python, env_type)

    ---@type venv-selector.LspClientConfig
    local cfg = { settings = merged_settings }

    if cmd_env.cmd_env and next(cmd_env.cmd_env) then
        cfg.cmd_env = cmd_env.cmd_env
    end

    return cfg
end

---Resolve project_root for a buffer; fall back to currently active root if available.
---@param bufnr integer
---@return string project_root
local function resolve_project_root(bufnr)
    local project_root = require("venv-selector.project_root").key_for_buf(bufnr) or ""
    if project_root == "" then
        local venv = require("venv-selector.venv")
        if type(venv.active_project_root) == "function" then
            local pr = venv.active_project_root()
            if type(pr) == "string" then
                project_root = pr
            end
        end
    end
    return project_root
end

---Restart python LSP clients for the given project root using the gate.
---Uses memoization per project_root to avoid repeating identical restarts.
---@param venv_python string|nil
---@param env_type venv-selector.VenvType|nil
---@param bufnr? integer
---@return boolean ok
---@return string? err
local function restart_all_python_lsps(venv_python, env_type, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    local project_root = resolve_project_root(bufnr)
    local py = venv_python or ""
    local ty = env_type or ""

    if project_root ~= "" then
        local last = last_restart_by_root[project_root]
        if last and last.py == py and last.ty == ty then
            log.debug(("restart_all_python_lsps: no-op (unchanged) root=%s py=%s type=%s"):format(project_root, py, ty))
            return true
        end
        last_restart_by_root[project_root] = { py = py, ty = ty }
    else
        log.debug("restart_all_python_lsps: project_root empty; not caching restart decision")
    end

    -- Optional visibility for debugging
    for _, c in ipairs(vim.lsp.get_clients()) do
        ---@diagnostic disable-next-line: undefined-field
        local fts = (c.config and c.config.filetypes) and table.concat(c.config.filetypes, ",") or ""
        local root = (c.config and c.config.root_dir) or ""
        log.debug(("lsp seen id=%d name=%s root=%s fts=[%s]"):format(c.id, c.name, root, fts))
    end

    ---@type table<string, {client:any, bufs:table<integer,true>, name:string, root:string}>
    local by_key = {}

    for _, c in ipairs(vim.lsp.get_clients()) do
        if is_python_lsp(c) then
            local root = (c.config and c.config.root_dir) or ""
            if project_root == "" or root == project_root then
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

    if not venv_python or venv_python == "" then
        log.debug("restart_all_python_lsps: venv_python=nil/empty, nothing to restart")
        return true
    end

    for key, entry in pairs(by_key) do
        local old_cfg = entry.client.config or {}
        local cfg = vim.deepcopy(old_cfg)

        local gen = default_lsp_settings(entry.name, venv_python, env_type)
        cfg.settings = gen.settings
        cfg.cmd_env = gen.cmd_env

        -- preserve key fields from old config
        cfg.capabilities = old_cfg.capabilities
        cfg.handlers = old_cfg.handlers
        cfg.on_attach = old_cfg.on_attach
        cfg.init_options = old_cfg.init_options

        -- gate key is name::root
        gate.request(key, cfg, entry.bufs)
    end

    return true
end

---Hook: restart python LSPs when a venv is activated.
---@param venv_python string|nil
---@param env_type venv-selector.VenvType|nil
---@param bufnr? integer
---@return integer count Number of LSP restarts requested (0 or 1)
function M.dynamic_python_lsp_hook(venv_python, env_type, bufnr)
    log.debug(("hook dynamic_python_lsp_hook venv=%s type=%s"):format(tostring(venv_python), tostring(env_type)))
    local ok = restart_all_python_lsps(venv_python, env_type, bufnr)
    return ok == true and 1 or 0
end

---Notify the user with throttling (per unique message, 1 second).
function M.send_notification(message)
    local now = vim.uv.hrtime()
    local last = M.notifications_memory[message]
    if last == nil or (now - last) > 1e9 then
        log.info(message)
        vim.notify(message, vim.log.levels.INFO, { title = "VenvSelect" })
        M.notifications_memory[message] = now
    else
        log.debug(message)
    end
end

return M
