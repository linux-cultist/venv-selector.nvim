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


---@type table<string, { py: string, ty: string }>
local last_restart_by_root = {}

-- Snapshot of original LSP configs before venv-selector first replaces them.
-- Keyed by the same gate key used for restarts.
---@type table<string, any>
local original_cfg_by_key = {}

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

M.is_python_lsp = is_python_lsp

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

---Compute the stable gate key used to scope restarts.
---Rooted clients use name::root:<root_dir>.
---Rootless clients use name::scope:<dir|buf:N> based on the current buffer.
---@param client any
---@param bufnr integer
---@return string gate_key
local function gate_key_for_client(client, bufnr)
    local root = (client.config and client.config.root_dir) or ""
    if root ~= "" then
        return client.name .. "::root:" .. root
    end

    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local dir = (bufname ~= "" and vim.fn.fnamemodify(bufname, ":p:h")) or ""
    local scope = (dir ~= "" and dir) or ("buf:%d"):format(bufnr)
    return client.name .. "::scope:" .. scope
end

---Snapshot an original client config once (only before the plugin first replaces it).
---@param gate_key string
---@param cfg any
local function snapshot_original_cfg(gate_key, cfg)
    if original_cfg_by_key[gate_key] ~= nil then
        return
    end
    if type(cfg) ~= "table" then
        return
    end

    local snap = vim.deepcopy(cfg)
    snap._venv_selector = nil
    original_cfg_by_key[gate_key] = snap
end

---Stop plugin-owned python LSP clients attached to a buffer.
---@param bufnr integer
---@return string[] stopped_keys Gate keys for the stopped clients
function M.stop_plugin_python_lsps_for_buf(bufnr)
    ---@type string[]
    local stopped_keys = {}
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
        if is_python_lsp(client) and client.config and client.config._venv_selector == true then
            local key = gate_key_for_client(client, bufnr)
            stopped_keys[#stopped_keys + 1] = key
            client:stop(true)
        end
    end
    return stopped_keys
end

---Restore baseline python LSP clients for a buffer by restarting with the snapshotted config.
---@param bufnr integer
---@param gate_keys string[]
function M.restore_original_python_lsps_for_buf(bufnr, gate_keys)
    for _, key in ipairs(gate_keys or {}) do
        local original = original_cfg_by_key[key]
        if original ~= nil then
            gate.request(key, vim.deepcopy(original), { [bufnr] = true })
        end
    end
end

---Clear restart memo for a specific project root so re-activating the same venv triggers restarts.
---@param project_root string|nil
function M.clear_restart_memo_for_root(project_root)
    if type(project_root) ~= "string" or project_root == "" then
        return
    end
    last_restart_by_root[project_root] = nil
end

---Create cmd_env for a client restart based on venv type.
---@param client_name string
---@param venv_python string|nil
---@param env_type venv-selector.VenvType|nil
---@return table cmd_env_wrap
local function create_cmd_env(client_name, venv_python, env_type)
    if not venv_python or venv_python == "" then
        return { cmd_env = {} }
    end

    local venv_path = vim.fn.fnamemodify(venv_python, ":h:h") -- .../venv
    local env = { cmd_env = {} }

    if env_type == "anaconda" then
        env.cmd_env.CONDA_PREFIX = venv_path
        log.trace(client_name .. ": Setting CONDA_PREFIX for conda environment: " .. venv_path)
    elseif env_type == "venv" or env_type == "uv" then
        env.cmd_env.VIRTUAL_ENV = venv_path
        log.trace(client_name .. ": Setting VIRTUAL_ENV for environment: " .. venv_path)
    else
        log.trace(client_name .. ": Unknown venv type: " .. tostring(env_type))
    end

    return env
end

---Generate venv-specific LSP settings, preserving existing user settings where possible.
---@param client_name string
---@param venv_python string|nil
---@param env_type venv-selector.VenvType|nil
---@return table cfg
local function default_lsp_settings(client_name, venv_python, env_type)
    if not venv_python or venv_python == "" then
        return { settings = {} }
    end

    local venv_dir          = vim.fn.fnamemodify(venv_python, ":h:h")
    local venv_name         = vim.fn.fnamemodify(venv_dir, ":t")
    local venv_path         = vim.fn.fnamemodify(venv_dir, ":h")

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

    local cfg = { settings = merged_settings }
    if cmd_env.cmd_env and next(cmd_env.cmd_env) then
        cfg.cmd_env = cmd_env.cmd_env
    end
    return cfg
end

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

local function log_lsp_clients_aligned()
    local clients = vim.lsp.get_clients()

    local max_id = 2
    local max_name = 4
    local max_root = 4

    local rows = {}

    for _, c in ipairs(clients) do
        local id = tostring(c.id or "")
        local name = c.name or ""
        local root = (c.config and c.config.root_dir) or ""
        local fts_tbl = (c.config and c.config.filetypes) or {}
        local fts = table.concat(fts_tbl, ",")

        max_id = math.max(max_id, #id)
        max_name = math.max(max_name, #name)
        max_root = math.max(max_root, #root)

        rows[#rows + 1] = { id = id, name = name, root = root, fts = fts }
    end

    max_root = math.min(max_root, 80)

    local fmt = string.format(
        "LSP Seen id=%%-%ds name=%%-%ds root=%%-%ds fts=[%%s]",
        max_id,
        max_name,
        max_root
    )

    for _, r in ipairs(rows) do
        local root = r.root
        if #root > max_root then
            root = root:sub(1, max_root - 1) .. "…"
        end
        log.debug(string.format(fmt, r.id, r.name, root, r.fts))
    end
end

---@param client any
---@param bufnr integer
---@return boolean
local function client_attached_to_buf(client, bufnr)
    local ab = client.attached_buffers
    if type(ab) == "table" then
        return ab[bufnr] == true
    end
    local bufs = attached_python_bufs(client)
    return bufs[bufnr] == true
end

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

    log_lsp_clients_aligned()

    ---@type table<string, { client:any, bufs:table<integer,true>, name:string }>
    local by_key = {}

    for _, c in ipairs(vim.lsp.get_clients()) do
        if is_python_lsp(c) then
            local root = (c.config and c.config.root_dir) or ""

            local include = false
            if root ~= "" then
                include = (project_root == "" or root == project_root)
            else
                include = client_attached_to_buf(c, bufnr)
            end

            if include then
                local gate_key = gate_key_for_client(c, bufnr)
                if not by_key[gate_key] then
                    by_key[gate_key] = {
                        client = c,
                        bufs = attached_python_bufs(c),
                        name = c.name,
                    }
                end
            end
        end
    end

    if next(by_key) == nil then
        log.trace("restart_all_python_lsps: no python LSP clients selected for this project_root")
        return false, "no python LSP clients selected for this project_root"
    end

    -- Memoize by root when possible (AFTER we know there are targets).
    if project_root ~= "" then
        local last = last_restart_by_root[project_root]
        if last and last.py == py and last.ty == ty then
            log.trace(("restart_all_python_lsps: no-op (unchanged) root=%s py=%s type=%s"):format(project_root, py, ty))
            return true
        end
        last_restart_by_root[project_root] = { py = py, ty = ty }
    else
        log.debug("restart_all_python_lsps: project_root empty; not caching restart decision")
    end

    if not venv_python or venv_python == "" then
        log.trace("restart_all_python_lsps: venv_python=nil/empty, nothing to restart")
        return true
    end

    for gate_key, entry in pairs(by_key) do
        local old_cfg = entry.client.config or {}

        if old_cfg._venv_selector ~= true then
            snapshot_original_cfg(gate_key, old_cfg)
        end

        local cfg = vim.deepcopy(old_cfg)
        cfg._venv_selector = true

        local gen = default_lsp_settings(entry.name, venv_python, env_type)
        cfg.settings = gen.settings
        cfg.cmd_env = gen.cmd_env

        cfg.capabilities = old_cfg.capabilities
        cfg.handlers = old_cfg.handlers
        cfg.on_attach = old_cfg.on_attach
        cfg.init_options = old_cfg.init_options

        cfg._venv_selector = true

        gate.request(gate_key, cfg, entry.bufs)
    end

    return true
end

---@param venv_python string|nil
---@param env_type venv-selector.VenvType|nil
---@param bufnr? integer
---@return integer
function M.dynamic_python_lsp_hook(venv_python, env_type, bufnr)
    log.trace(("Hook dynamic_python_lsp_hook called venv=%s type=%s"):format(tostring(venv_python), tostring(env_type)))
    local ok = restart_all_python_lsps(venv_python, env_type, bufnr)
    return ok == true and 1 or 0
end

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
