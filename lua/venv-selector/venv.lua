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

---Last activated project root (derived from project_root.key_for_buf on activation).
---@type string|nil
local active_project_root = nil

---Return the last activated project root.
---
---@return string|nil root
function M.active_project_root()
    return active_project_root
end

---Global source tag for UI/debug (e.g. "workspace", "cwd", "pipx", "anaconda").
---This is written by the search layer and cached_venv restore paths.
---@type string|nil
path.current_source = nil

---Stop python LSP servers via configured hooks.
---This calls each hook with nil parameters; hooks should interpret this as "stop/deactivate".
function M.stop_lsp_servers()
    local hooks = require("venv-selector.config").user_settings.hooks
    for _, hook in pairs(hooks) do
        hook(nil, nil, nil)
    end
end

---Set the source tag that the UI/picker can display (and cache can persist).
---
---@param source string
function M.set_source(source)
    log.debug('Setting require("venv-selector").source() to \'' .. source .. "'")
    path.current_source = source
end

-- ============================================================================
-- Activation core
-- ============================================================================

---Internal activation implementation.
---This is the only place that should perform activation side-effects.
---
---Side-effects:
--- - Update global state:
---     path.current_python_path
---     path.current_venv_path
---     path.current_type
---     active_project_root
--- - Update session-local per-buffer memory:
---     vim.b[bufnr].venv_selector_last_python
---     vim.b[bufnr].venv_selector_last_type
--- - Notify hooks (typically LSP restart logic)
--- - Persist cache unless opts.save_cache == false
--- - Update PATH + environment variables
--- - Call on_venv_activate_callback if configured
---
---@param python_path string Absolute path to python executable
---@param env_type string Environment type (e.g. "venv"|"conda"|"uv")
---@param bufnr? integer Buffer associated with this activation (for per-buffer memory + root)
---@param opts? { save_cache?: boolean, check_lsp?: boolean }
---@return boolean activated True if activation succeeded (or was already active)
local function do_activate(python_path, env_type, bufnr, opts)
    opts = opts or {}

    if not python_path or python_path == "" then
        return false
    end

    if vim.fn.filereadable(python_path) ~= 1 then
        log.debug("Venv `" .. tostring(python_path) .. "` doesnt exist so cant activate it.")
        return false
    end

    env_type = env_type or "venv"

    -- Skip if already active (prevents redundant PATH updates + LSP restarts).
    if path.current_python_path == python_path and path.current_type == env_type then
        log.debug(("Activation skipped (already active): py=%s type=%s"):format(python_path, env_type))
        vim.g.venv_selector_activated = true
        active_project_root = require("venv-selector.project_root").key_for_buf(bufnr)
        return true
    end

    -- Update global state used by UI/sorting.
    path.current_python_path = python_path
    path.current_venv_path = path.get_base(python_path)
    path.current_type = env_type

    -- Remember per-buffer selection for session switching (works even if cache is disabled).
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.b[bufnr].venv_selector_last_python = python_path
        vim.b[bufnr].venv_selector_last_type = env_type
    end

    -- Update current activated project root for root-scoped logic (LSP/cache/UI).
    local pr = require("venv-selector.project_root").key_for_buf(bufnr)
    active_project_root = pr

    -- Inform LSP servers via hooks (hooks should be gated/deduped by root).
    local count = 0
    local hooks = require("venv-selector.config").user_settings.hooks
    for _, hook in pairs(hooks) do
        count = count + hook(python_path, env_type, bufnr)
    end

    -- Optional legacy behavior: require python LSPs to exist before activation.
    -- Keeping as commented reference; if re-enabled, it should live here only.
    -- if opts.check_lsp and count == 0 and config.user_settings.options.require_lsp_activation == true then
    --     local message =
    --         "No python LSP servers are running. Please open a python file and then select a venv to activate."
    --     vim.notify(message, vim.log.levels.INFO, { title = "VenvSelect" })
    --     log.info(message)
    --     return false
    -- end

    -- Save to cache (cached_venv.save skips "uv" internally).
    -- Pass bufnr so cache key can be root-scoped.
    local cache = require("venv-selector.cached_venv")
    if opts.save_cache ~= false then
        cache.save(python_path, env_type, bufnr)
    else
        log.debug("Skipping cache save (activation initiated from cache)")
    end

    -- Update PATH/env/dap/etc
    M.update_paths(python_path, env_type)

    -- Optional user callback after activation and path/env updates.
    local on_venv_activate_callback = config.user_settings.options.on_venv_activate_callback
    if on_venv_activate_callback ~= nil then
        log.debug("Calling on_venv_activate_callback() function")
        on_venv_activate_callback()
    end

    vim.g.venv_selector_activated = true
    return true
end

-- ============================================================================
-- Public activation entrypoints
-- ============================================================================

---Buffer-aware activation entrypoint.
---Use this everywhere that can be tied to a specific buffer (uv, cache restore, BufEnter restore).
---
---@param python_path string Absolute path to python executable
---@param env_type string Environment type (e.g. "venv"|"conda"|"uv")
---@param bufnr? integer Buffer number used for per-buffer memory + project root
---@param opts? { save_cache?: boolean }
---@return boolean activated
function M.activate_for_buffer(python_path, env_type, bufnr, opts)
    opts = opts or {}

    -- Sanitize bufnr: only keep valid "normal" buffers.
    if bufnr ~= nil then
        if (not vim.api.nvim_buf_is_valid(bufnr)) or vim.bo[bufnr].buftype ~= "" then
            bufnr = nil
        end
    end

    return do_activate(python_path, env_type, bufnr, opts)
end

---Backwards-compatible activation API used by picker and legacy call-sites.
---Uses the current buffer as the activation context.
---
---@param python_path string Absolute path to python executable
---@param env_type string Environment type
---@return boolean activated
function M.activate(python_path, env_type)
    local bufnr = vim.api.nvim_get_current_buf()
    return M.activate_for_buffer(python_path, env_type, bufnr, { save_cache = true })
end

-- ============================================================================
-- PATH + env var management
-- ============================================================================

---Apply PATH, dap-python, and environment variables for the activated interpreter.
---
---Notes:
--- - `venv_path` here is actually the python executable path in current call-sites.
--- - PATH is updated using `path.add(path.get_base(venv_path))` which prepends the bin/Scripts dir.
---
---@param venv_path string Absolute path to python executable
---@param env_type string Environment type (e.g. "venv"|"conda"|"uv"|"anaconda")
function M.update_paths(venv_path, env_type)
    -- PATH: prepend the python bin directory.
    path.add(path.get_base(venv_path))

    -- Update dap-python resolver.
    path.update_python_dap(venv_path)

    -- Update exported plugin globals (python() + venv()).
    path.save_selected_python(venv_path)

    -- Environment variables based on venv type.
    if env_type == "uv" then
        -- Current behavior: do not set VIRTUAL_ENV for UV envs.
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
        M.set_env(base_path, "CONDA_PREFIX")
    else
        local base_path = path.get_base(path.get_base(venv_path))
        M.unset_env("CONDA_PREFIX")
        M.set_env(base_path, "VIRTUAL_ENV")
    end
end

---Set an environment variable if enabled in configuration.
---
---@param env_variable_value string
---@param env_variable_name string
function M.set_env(env_variable_value, env_variable_name)
    if config.user_settings.options.set_environment_variables == true then
        vim.fn.setenv(env_variable_name, env_variable_value)
        log.debug("Shell environment variable $" .. env_variable_name .. " set to " .. env_variable_value)
    end
end

---Unset an environment variable if enabled in configuration.
---
---@param env_variable_name string
function M.unset_env(env_variable_name)
    if config.user_settings.options.set_environment_variables == true then
        if vim.fn.getenv(env_variable_name) ~= nil then
            vim.env[env_variable_name] = nil
            log.debug("Shell environment variable $" .. env_variable_name .. " has been unset.")
        end
    end
end

---Unset venv-related environment variables unconditionally (used by deactivate flow).
function M.unset_env_variables()
    vim.env.VIRTUAL_ENV = nil
    vim.env.CONDA_PREFIX = nil
end

---@cast M venv-selector.VenvModule
return M
