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

require("venv-selector.types")

local M = {}






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
function M.activate_from_path(python_path, env_type)
    require("venv-selector.venv").activate(python_path, env_type)
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

    local autocmds = require("venv-selector.autocmds")
    autocmds.create()

    local config = require("venv-selector.config")
    config.store(conf)

    if not valid_fd() then
        return
    end

    setup_notify()
    setup_highlight()

    require("venv-selector.user_commands").register()
end

---@cast M venv-selector.InitModule
return M
