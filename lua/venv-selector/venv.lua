local path = require("venv-selector.path")
local config = require("venv-selector.config")
local log = require("venv-selector.logger")

local M = {}
local active_project_root = nil

function M.active_project_root()
    return active_project_root
end

path.current_source = nil -- contains the name of the search, like anaconda, pipx etc.

function M.stop_lsp_servers()
    local hooks = require("venv-selector.config").user_settings.hooks
    for _, hook in pairs(hooks) do
        hook(nil, nil, nil)
    end
end

function M.set_source(source)
    log.debug('Setting require("venv-selector").source() to \'' .. source .. "'")
    path.current_source = source
end

-- Internal: apply UI/global state + call hooks + cache/save + update env/PATH.
-- This is the single activation implementation.
---@param python_path string
---@param env_type string
---@param bufnr? integer
---@param check_lsp? boolean
---@return boolean activated
local function do_activate(python_path, env_type, bufnr, opts)
    if not python_path or python_path == "" then
        return false
    end

    if vim.fn.filereadable(python_path) ~= 1 then
        log.debug("Venv `" .. tostring(python_path) .. "` doesnt exist so cant activate it.")
        return false
    end

    env_type = env_type or "venv"

    -- If already active, skip (prevents pointless LSP restarts on buffer enter / cache restore)
    if path.current_python_path == python_path and path.current_type == env_type then
        log.debug(("Activation skipped (already active): py=%s type=%s"):format(python_path, env_type))
        vim.g.venv_selector_activated = true
        active_project_root = require("venv-selector.project_root").key_for_buf(bufnr)
        return true
    end

    -- Update global state used by UI/sorting
    path.current_python_path = python_path
    path.current_venv_path = path.get_base(python_path)
    path.current_type = env_type


    local pr = require("venv-selector.project_root").key_for_buf(bufnr)
    active_project_root = pr

    -- Inform LSP servers via hooks (hooks should use restart gate)
    local count = 0
    local hooks = require("venv-selector.config").user_settings.hooks
    for _, hook in pairs(hooks) do
        count = count + hook(python_path, env_type, bufnr)
    end

    -- -- Optional behavior: keep the old API shape (currently you disabled this check in activate()).
    -- -- If you ever want it back, it should live here, not duplicated.
    -- if check_lsp and count == 0 and config.user_settings.options.require_lsp_activation == true then
    --     local message =
    --     "No python LSP servers are running. Please open a python file and then select a venv to activate."
    --     vim.notify(message, vim.log.levels.INFO, { title = "VenvSelect" })
    --     log.info(message)
    --     return false
    -- end

    -- Save to cache (skip uv inside cached_venv.save)
    -- Pass bufnr so cache can be per-root/per-workspace.
    local cache = require("venv-selector.cached_venv")
    -- if type(cache.save) == "function" then
    --     cache.save(python_path, env_type, bufnr)
    -- end
    if opts.save_cache ~= false then
        cache.save(python_path, env_type, bufnr)
    else
        log.debug("Skipping cache save (activation initiated from cache)")
    end

    -- Update PATH/env/dap/etc
    M.update_paths(python_path, env_type)

    local on_venv_activate_callback = config.user_settings.options.on_venv_activate_callback
    if on_venv_activate_callback ~= nil then
        log.debug("Calling on_venv_activate_callback() function")
        on_venv_activate_callback()
    end

    vim.g.venv_selector_activated = true
    return true
end

-- Buffer-aware activation entrypoint (use this everywhere new: uv, cache restore, buffer enter restore)
---@param python_path string
---@param env_type string
---@param bufnr? integer
---@return boolean activated
function M.activate_for_buffer(python_path, env_type, bufnr, opts)
    opts = opts or {}
    if bufnr ~= nil then
        if (not vim.api.nvim_buf_is_valid(bufnr)) or vim.bo[bufnr].buftype ~= "" then
            bufnr = nil
        end
    end
    return do_activate(python_path, env_type, bufnr, opts)
end

--- Backwards-compatible API used by picker, etc.
---@param python_path string
---@param env_type string
---@param check_lsp boolean
---@return boolean activated
function M.activate(python_path, env_type, check_lsp)
    local bufnr = vim.api.nvim_get_current_buf()
    return M.activate_for_buffer(python_path, env_type, bufnr, { save_cache = true, check_lsp = check_lsp })
end

function M.update_paths(venv_path, env_type)
    path.add(path.get_base(venv_path))
    path.update_python_dap(venv_path)
    path.save_selected_python(venv_path)

    -- Handle environment variables based on venv type
    if env_type == "uv" then
        -- Your current behavior: do not set VIRTUAL_ENV for UV envs
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

function M.set_env(env_variable_value, env_variable_name)
    if config.user_settings.options.set_environment_variables == true then
        vim.fn.setenv(env_variable_name, env_variable_value)
        log.debug("Shell environment variable $" .. env_variable_name .. " set to " .. env_variable_value)
    end
end

function M.unset_env(env_variable_name)
    if config.user_settings.options.set_environment_variables == true then
        if vim.fn.getenv(env_variable_name) ~= nil then
            vim.env[env_variable_name] = nil
            log.debug("Shell environment variable $" .. env_variable_name .. " has been unset.")
        end
    end
end

function M.unset_env_variables()
    vim.env.VIRTUAL_ENV = nil
    vim.env.CONDA_PREFIX = nil
end

return M
