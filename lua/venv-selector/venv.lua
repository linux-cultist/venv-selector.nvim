-- lua/venv-selector/venv.lua
--
-- Activation + global state coordinator for venv-selector.nvim.
--
-- Responsibilities:
-- - Single activation implementation (do_activate):
--     - Validate interpreter exists
--     - Skip if already active
--     - Update global state (path.current_*)
--     - Record per-buffer session state (vim.b[bufnr].venv_selector_last_*)
--     - Update active project root (for UI + cache + LSP scoping)
--     - Invoke hooks (LSP restart hook should be gated)
--     - Save cache (unless opts.save_cache=false; uv caches are skipped in cached_venv.save)
--     - Update PATH and environment variables
--     - Call optional user callback
-- - Provide buffer-aware activation entrypoint: activate_for_buffer()
-- - Provide backwards-compatible activation entrypoint: activate()
-- - Environment variable helpers (set/unset)
--
-- Design notes:
-- - active_project_root is a module-local value so it can be used as a stable "last activated" root.
-- - Per-buffer session memory enables correct switching even when persistent cache is disabled.

require("venv-selector.types")
local path = require("venv-selector.path")
local config = require("venv-selector.config")
local log = require("venv-selector.logger")

local M = {}

---@type string|nil
local active_project_root = nil

---@return string|nil
function M.active_project_root()
    return active_project_root
end

---@param bufnr? integer
function M.clear_active_state(bufnr)
    path.current_python_path = nil
    path.current_venv_path = nil
    path.current_type = nil
    path.current_source = nil
    active_project_root = nil
    vim.g.venv_selector_activated = false

    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.b[bufnr].venv_selector_cached_applied = nil
        vim.b[bufnr].venv_selector_last_python = nil
        vim.b[bufnr].venv_selector_last_type = nil
    end
end

---@type string|nil
path.current_source = nil


---@param source string
function M.set_source(source)
    log.trace('Setting require("venv-selector").source() to \'' .. source .. "'")
    path.current_source = source
end

---@param python_path string
---@param env_type string
---@param bufnr? integer
---@param opts? { save_cache?: boolean, check_lsp?: boolean }
---@return boolean
local function do_activate(python_path, env_type, bufnr, opts)
    opts = opts or {}

    if not python_path or python_path == "" then
        return false
    end

    if vim.fn.filereadable(python_path) ~= 1 then
        return false
    end

    env_type = env_type or "venv"

    if path.current_python_path == python_path and path.current_type == env_type then
        vim.g.venv_selector_activated = true
        active_project_root = require("venv-selector.project_root").key_for_buf(bufnr)
        return true
    end

    path.current_python_path = python_path
    path.current_venv_path = path.get_base(python_path)
    path.current_type = env_type

    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.b[bufnr].venv_selector_last_python = python_path
        vim.b[bufnr].venv_selector_last_type = env_type
    end

    local pr = require("venv-selector.project_root").key_for_buf(bufnr)
    active_project_root = pr

    local count = 0
    local hooks = require("venv-selector.config").user_settings.hooks
    for _, hook in pairs(hooks) do
        count = count + hook(python_path, env_type, bufnr)
    end

    local cache = require("venv-selector.cached_venv")
    if opts.save_cache ~= false then
        cache.save(python_path, env_type, bufnr)
    end

    M.update_paths(python_path, env_type)

    local on_venv_activate_callback = config.user_settings.options.on_venv_activate_callback
    if on_venv_activate_callback ~= nil then
        on_venv_activate_callback()
    end

    vim.g.venv_selector_activated = true
    return true
end

---@param python_path string
---@param env_type string
---@param bufnr? integer
---@param opts? { save_cache?: boolean }
---@return boolean
function M.activate_for_buffer(python_path, env_type, bufnr, opts)
    opts = opts or {}

    if bufnr ~= nil then
        if (not vim.api.nvim_buf_is_valid(bufnr)) or vim.bo[bufnr].buftype ~= "" then
            bufnr = nil
        end
    end

    -- Manual activation clears per-buffer disable flag.
    -- Convention: picker/user activation uses save_cache=true (default); auto-restore uses save_cache=false.
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) and opts.save_cache ~= false then
        vim.b[bufnr].venv_selector_disabled = nil
    end

    return do_activate(python_path, env_type, bufnr, opts)
end

---@param python_path string
---@param env_type venv-selector.VenvType
---@return boolean
function M.activate(python_path, env_type)
    local bufnr = vim.api.nvim_get_current_buf()
    return M.activate_for_buffer(python_path, env_type, bufnr, { save_cache = true })
end

---@param venv_path string
---@param env_type string
function M.update_paths(venv_path, env_type)
    path.add(path.get_base(venv_path))
    path.update_python_dap(venv_path)
    path.save_selected_python(venv_path)

    if env_type == "uv" then
        M.unset_env("VIRTUAL_ENV")
        M.unset_env("CONDA_PREFIX")
    elseif env_type == "anaconda" then
        M.unset_env("VIRTUAL_ENV")

        local base_path
        if vim.fn.has("Win32") == 1 then
            base_path = path.get_base(venv_path)
        else
            base_path = path.get_base(path.get_base(venv_path))
        end

        if base_path then
            M.set_env(base_path, "CONDA_PREFIX")
        else
            M.unset_env("CONDA_PREFIX")
        end
    else
        local base_path = path.get_base(path.get_base(venv_path))
        M.unset_env("CONDA_PREFIX")

        if base_path then
            M.set_env(base_path, "VIRTUAL_ENV")
        else
            M.unset_env("VIRTUAL_ENV")
        end
    end
end

---@param env_variable_value string
---@param env_variable_name string
function M.set_env(env_variable_value, env_variable_name)
    if config.user_settings.options.set_environment_variables == true then
        vim.fn.setenv(env_variable_name, env_variable_value)
    end
end

---@param env_variable_name string
function M.unset_env(env_variable_name)
    if config.user_settings.options.set_environment_variables == true then
        if vim.fn.getenv(env_variable_name) ~= nil then
            vim.env[env_variable_name] = nil
        end
    end
end

function M.unset_env_variables()
    vim.env.VIRTUAL_ENV = nil
    vim.env.CONDA_PREFIX = nil
end

return M
