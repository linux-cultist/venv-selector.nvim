-- lua/venv-selector/init.lua
--
-- Main entrypoint for venv-selector.nvim.
--
-- Responsibilities:
-- - Register autocmds that restore environments on buffer lifecycle events:
--   - One-shot persistent cache restore per python buffer (non-uv).
--   - Per-enter restore flow (buffer-local restore, persistent cache restore, uv restore).
--   - Re-run uv workflow on writes for PEP 723 buffers.
-- - Expose a small public API for status queries and actions (activate/deactivate/stop LSP).
-- - Provide `setup()` that finalizes configuration, validates prerequisites (Neovim version, fd),
--   and registers user commands.
--
-- Design notes:
-- - "Normal python buffers" are buftype="" and filetype="python".
-- - The one-shot cache autocmd avoids re-triggering persistent cache restore for the same buffer.
-- - The BufEnter autocmd is critical for session restore and already-loaded buffers.
-- - uv detection/activation is delegated to `uv2.lua` and is always run last in the enter flow.
--
-- Conventions:
-- - env_type values are: "venv" | "conda" | "uv".
-- - Public status helpers reflect the current state tracked by `path.lua`.


local M = {}

---@return string|nil
function M.python()
    return require("venv-selector.path").current_python_path
end

---@return string|nil
function M.venv()
    return require("venv-selector.path").current_venv_path
end

---@return string|nil
function M.source()
    return require("venv-selector.path").current_source
end

---@return string[]
function M.workspace_paths()
    return require("venv-selector.workspace").list_folders(vim.api.nvim_get_current_buf())
end

---@return string
function M.cwd()
    return vim.fn.getcwd()
end

---@return string|nil
function M.file_dir()
    return require("venv-selector.path").get_current_file_directory()
end

function M.restart_lsp_servers()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Clear memo so "same venv" triggers a restart.
    local hooks = require("venv-selector.hooks")
    local pr = require("venv-selector.project_root").key_for_buf(bufnr) or ""
    hooks.clear_restart_memo_for_root(pr)

    -- Re-run hooks with current active venv (forces gate.request restarts).
    -- This assumes your active state fields exist (path.current_python_path/current_type).
    local path = require("venv-selector.path")
    local py = path.current_python_path
    local ty = path.current_type

    local user_hooks = require("venv-selector.config").user_settings.hooks or {}
    for _, hook in pairs(user_hooks) do
        pcall(hook, py, ty, bufnr)
    end
end

function M.stop_lsp_servers()
    local bufnr = vim.api.nvim_get_current_buf()

    -- 1) Always stop plugin-owned python LSP clients for this buffer.
    local hooks_mod = require("venv-selector.hooks")
    hooks_mod.stop_plugin_python_lsps_for_buf(bufnr)

    -- Ensure selecting the same venv again triggers restarts.
    local pr = require("venv-selector.project_root").key_for_buf(bufnr) or ""
    hooks_mod.clear_restart_memo_for_root(pr)

    -- 2) Optional: notify user hooks for any additional cleanup they want.
    -- Convention: (nil,nil,bufnr) means "stop/cleanup".
    local hooks = require("venv-selector.config").user_settings.hooks or {}
    for _, hook in pairs(hooks) do
        pcall(hook, nil, nil, bufnr)
    end
end

---@param python_path string
---@param env_type venv-selector.VenvType
function M.activate_from_path(python_path, env_type)
    require("venv-selector.venv").activate(python_path, env_type)
end

function M.deactivate()
    local bufnr = vim.api.nvim_get_current_buf()

    -- Prevent auto-restore (BufEnter/cache/uv) from re-activating this buffer.
    if vim.api.nvim_buf_is_valid(bufnr) then
        vim.b[bufnr].venv_selector_disabled = true
    end

    -- Capture root before clearing state; used to clear hook memoization.
    local project_root = require("venv-selector.project_root").key_for_buf(bufnr) or ""

    local hooks = require("venv-selector.hooks")

    -- 1) Stop only plugin-owned python LSP clients attached to this buffer.
    local stopped_keys = hooks.stop_plugin_python_lsps_for_buf(bufnr)

    -- Clear restart memo so selecting the same venv again forces restart.
    hooks.clear_restart_memo_for_root(project_root)

    -- 2) Clear plugin active state so re-activation is not skipped.
    require("venv-selector.venv").clear_active_state(bufnr)

    -- 3) Restore baseline python LSP configs.
    hooks.restore_original_python_lsps_for_buf(bufnr, stopped_keys)

    -- 4) PATH/env cleanup.
    require("venv-selector.path").remove_current()
    require("venv-selector.venv").unset_env_variables()
end

local function setup_notify()
    local options = require("venv-selector.config").get_user_options()
    if options and options.override_notify then
        local has_notify, notify_plugin = pcall(require, "notify")
        if has_notify and notify_plugin then
            vim.notify = notify_plugin
        end
    end
end

---@return boolean
local function check_nvim_version()
    local version = vim.version()
    if version.major == 0 and version.minor < 11 then
        local error_msg = string.format(
            "venv-selector.nvim requires Neovim 0.11+. Current version: %d.%d.%d\n" ..
            "Please upgrade Neovim or remove venv-selector.nvim from your configuration.",
            version.major, version.minor, version.patch
        )
        vim.notify(error_msg, vim.log.levels.ERROR, { title = "VenvSelect" })
        return false
    end
    return true
end

local function setup_highlight()
    local options = require("venv-selector.config").get_user_options()
    vim.api.nvim_set_hl(0, "VenvSelectActiveVenv", { fg = options.selected_venv_marker_color })
end

---@return boolean
local function valid_fd()
    local options = require("venv-selector.config").user_settings.options
    if options.fd_binary_name == nil then
        local message =
        "Cannot find any fd binary on your system. If it is installed under a different name, set options.fd_binary_name."
        require("venv-selector.logger").error(message)
        vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
        return false
    end
    return true
end

---@param conf venv-selector.Settings|nil
function M.setup(conf)
    if not check_nvim_version() then
        return
    end

    conf = conf or {}

    require("venv-selector.logger").setup_debug_logging(conf)

    local config = require("venv-selector.config")
    config.store(conf)

    require("venv-selector.autocmds").create()

    if not valid_fd() then
        return
    end

    setup_notify()
    setup_highlight()

    require("venv-selector.user_commands").register()
end

---@cast M venv-selector.InitModule
return M
