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

---@alias venv-selector.VenvType "venv"|"conda"|"uv"

---@class venv-selector.Settings
---@field cache? { file?: string }
---@field hooks? fun(venv_python: string|nil, env_type: string|nil, bufnr?: integer)[]
---@field options? table

---@class venv-selector.AutocmdArgs
---@field buf integer

---Return true if the buffer is a normal on-disk python buffer (not a special buftype).
---@param bufnr integer
---@return boolean ok
local function is_normal_python_buf(bufnr)
    return vim.api.nvim_buf_is_valid(bufnr)
        and vim.bo[bufnr].buftype == ""
        and vim.bo[bufnr].filetype == "python"
end

-- ============================================================
-- Cached venv initial restore (one-shot per buffer)
-- ============================================================

local group_cache = vim.api.nvim_create_augroup("VenvSelectorCachedVenv", { clear = true })

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "FileType" }, {
    group = group_cache,
    callback = function(args)
        ---@cast args venv-selector.AutocmdArgs
        local bufnr = args.buf
        if not is_normal_python_buf(bufnr) then
            return
        end

        -- Skip uv buffers
        local uv2 = require("venv-selector.uv2")
        if uv2.is_uv_buffer(bufnr) then
            return
        end

        -- one-shot per buffer
        if vim.b[bufnr].venv_selector_cache_checked then
            return
        end
        vim.b[bufnr].venv_selector_cache_checked = true

        -- If this project is already active globally, do not trigger a cache restore.
        local pr = require("venv-selector.project_root").key_for_buf(bufnr)
        local venv = require("venv-selector.venv")
        if pr and type(venv.active_project_root) == "function" and venv.active_project_root() == pr then
            require("venv-selector.logger").debug(
                ("cache-autocmd skip (project already active) b=%d root=%s"):format(bufnr, pr)
            )
            return
        end

        require("venv-selector.logger").debug(
            ("cache-autocmd once b=%d file=%s"):format(bufnr, vim.api.nvim_buf_get_name(bufnr))
        )

        -- Defer: allow project root detection / session restore / filetype to settle
        vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(bufnr) then
                require("venv-selector.cached_venv").retrieve(bufnr)
            end
        end, 1000)
    end,
})

-- ============================================================
-- Buffer-enter restoration + uv handling
-- ============================================================

local uv_group = vim.api.nvim_create_augroup("VenvSelectorUvDetect", { clear = true })

---Run the complete “restore/activate” flow for a python buffer, in priority order.
---This function is intentionally used by multiple autocmds to cover session restore and late filetype.
---
---@param bufnr integer
---@param reason "read"|"filetype"|"enter"
local function uv_maybe_activate(bufnr, reason)
    if not is_normal_python_buf(bufnr) then
        return
    end

    local log = require("venv-selector.logger")
    log.debug(("uv-autocmd %s b=%d file=%s"):format(reason, bufnr, vim.api.nvim_buf_get_name(bufnr)))

    local cached = require("venv-selector.cached_venv")
    local uv2 = require("venv-selector.uv2")

    -- 1) session-local per-buffer restore (works even if persistent cache is disabled)
    cached.ensure_buffer_last_venv_activated(bufnr)

    -- 2) persistent cache restore (no-op if cache disabled)
    cached.ensure_cached_venv_activated(bufnr)

    -- 3) uv restore (PEP 723)
    uv2.ensure_uv_buffer_activated(bufnr)
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = uv_group,
    callback = function(args)
        ---@cast args venv-selector.AutocmdArgs
        uv_maybe_activate(args.buf, "read")
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    group = uv_group,
    pattern = "python",
    callback = function(args)
        ---@cast args venv-selector.AutocmdArgs
        uv_maybe_activate(args.buf, "filetype")
    end,
})

-- Critical: catches session restore, already-loaded buffers, and window switches
vim.api.nvim_create_autocmd("BufEnter", {
    group = uv_group,
    callback = function(args)
        ---@cast args venv-selector.AutocmdArgs
        uv_maybe_activate(args.buf, "enter")
    end,
})

-- When user edits metadata, re-run uv flow
vim.api.nvim_create_autocmd("BufWritePost", {
    group = uv_group,
    callback = function(args)
        ---@cast args venv-selector.AutocmdArgs
        local bufnr = args.buf
        if not is_normal_python_buf(bufnr) then
            return
        end
        require("venv-selector.uv2").run_uv_flow_if_needed(bufnr)
    end,
})

-- ============================================================
-- Public API (status helpers + actions)
-- ============================================================

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
    return require("venv-selector.workspace").list_folders()
end

---@return string
function M.cwd()
    return vim.fn.getcwd()
end

---@return string|nil
function M.file_dir()
    return require("venv-selector.path").get_current_file_directory()
end

---Stop all python LSP servers managed by the plugin (delegates to venv.lua).
function M.stop_lsp_servers()
    require("venv-selector.venv").stop_lsp_servers()
end

---Activate an environment given an explicit python executable path.
---@param python_path string
function M.activate_from_path(python_path)
    require("venv-selector.venv").activate(python_path, "activate_from_path", true)
end

---Deactivate the current environment:
---- removes the venv PATH prefix
---- unsets plugin-managed environment variables
function M.deactivate()
    require("venv-selector.path").remove_current()
    require("venv-selector.venv").unset_env_variables()
end

-- ============================================================
-- Setup helpers
-- ============================================================

---Initialize nvim-notify if available and enabled.
local function setup_notify()
    local options = require("venv-selector.config").get_user_options()
    if options and options.override_notify then
        local has_notify, notify_plugin = pcall(require, "notify")
        if has_notify and notify_plugin then
            vim.notify = notify_plugin
        end
    end
end

---Check if Neovim version meets minimum requirements.
---@return boolean ok
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

---Enable debug logging if requested.
---@param conf venv-selector.Settings|nil
local function setup_debug_logging(conf)
    if conf and conf.options and conf.options.debug then
        local logmod = require("venv-selector.logger")
        logmod.enabled = true
    end
end

---Setup highlight group for selected venv marker.
local function setup_highlight()
    local options = require("venv-selector.config").get_user_options()
    vim.api.nvim_set_hl(0, "VenvSelectActiveVenv", { fg = options.selected_venv_marker_color })
end

---Validate fd availability. fd_binary_name should already be set by config finalization.
---@return boolean ok
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

---Setup plugin configuration, commands, and integrations.
---@param conf venv-selector.Settings|nil User configuration
function M.setup(conf)
    if not check_nvim_version() then
        return
    end

    -- Run this first so we have logging enabled when we print the config
    setup_debug_logging(conf)

    local config = require("venv-selector.config")
    config.store(conf)

    if not valid_fd() then
        return
    end

    setup_notify()
    setup_highlight()

    require("venv-selector.user_commands").register()
end

return M
