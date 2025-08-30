
local function on_lsp_attach(args)
    if vim.bo.filetype == "python" then
        local cache = require("venv-selector.cached_venv")
        cache.handle_automatic_activation()
    end
end

vim.api.nvim_create_autocmd("LspAttach", {
    pattern = "*",
    callback = on_lsp_attach,
})

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

---@param plugin_settings venv-selector.Config
function M.setup(conf)
    if vim.tbl_get(conf, "options", "debug") then
        local log = require("venv-selector.logger")
        log.enabled = true
    end

    local config = require("venv-selector.config")
    config.merge_user_settings(conf or {}) -- creates config.user_settings variable with configuration
    local user_commands = require("venv-selector.user_commands")
    user_commands.register()

    vim.api.nvim_command("hi VenvSelectActiveVenv guifg=" .. config.user_settings.options.telescope_active_venv_color)
end

-- Initialize UV auto-activation
local uv = require("venv-selector.uv")
uv.setup_auto_activation()

return M
