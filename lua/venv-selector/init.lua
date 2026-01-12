local M = {}

function M.python()
    return require("venv-selector.path").current_python_path
end

function M.venv()
    return require("venv-selector.path").current_venv_path
end

function M.source()
    return require("venv-selector.path").current_source
end

function M.workspace_paths()
    return require("venv-selector.workspace").list_folders()
end

function M.cwd()
    return vim.fn.getcwd()
end

function M.file_dir()
    return require("venv-selector.path").get_current_file_directory()
end

function M.stop_lsp_servers()
    require("venv-selector.venv").stop_lsp_servers()
end

function M.activate_from_path(python_path)
    require("venv-selector.venv").activate(python_path, "activate_from_path", true)
end

function M.deactivate()
    require("venv-selector.path").remove_current()
    require("venv-selector.venv").unset_env_variables()
end

---Initialize nvim-notify if available
local function setup_notify()
    local has_notify, notify_plugin = pcall(require, "notify")
    if has_notify then
        vim.notify = notify_plugin
    end
end

---Check if Neovim version meets minimum requirements
---@return boolean true if version is compatible, false otherwise
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

---Enable debug logging if requested
---@param conf table|nil
local function setup_debug_logging(conf)
    if conf and conf.options and conf.options.debug then
        local log = require("venv-selector.logger")
        log.enabled = true
    end
end

---Setup highlight group for selected venv marker
---@param settings venv-selector.Settings
local function setup_highlight(settings)
    vim.api.nvim_set_hl(0, "VenvSelectActiveVenv", {
        fg = settings.options.selected_venv_marker_color
    })
end

---Setup plugin configuration, commands, and integrations
---@param conf venv-selector.Settings|nil User configuration
function M.setup(conf)
    if not check_nvim_version() then
        return
    end

    setup_debug_logging(conf)
    setup_notify()

    local config = require("venv-selector.config")
    config.store(conf)

    setup_highlight(config.user_settings)

    require("venv-selector.user_commands").register()

    local uv = require("venv-selector.uv")
    uv.setup_auto_activation()
end

return M
