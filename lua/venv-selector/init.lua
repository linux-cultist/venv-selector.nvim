-- local log = require("venv-selector.logger")
-- local user_commands = require("venv-selector.user_commands")
-- local config = require("venv-selector.config")
-- local venv = require("venv-selector.venv")
-- local path = require("venv-selector.path")
-- local ws = require("venv-selector.workspace")

local function on_lsp_attach()
    if vim.bo.filetype == "python" then
        local config = require("venv-selector.config")
        local cache = require("venv-selector.cached_venv")
        if config.user_settings.options.cached_venv_automatic_activation == true then
            cache.retrieve()
        end
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

-- Temporary, will be removed later.
function M.split_command(str)
    local ut = require("venv-selector.utils")
    return ut.split_cmd_for_windows(str)
end

function M.deactivate()
    require("venv-selector.path").remove_current()
    require("venv-selector.path").unset_env_variables()
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
    
    vim.notify("Important: VenvSelect is now using `main` as the updated branch again. Please remove `branch = regexp` from your config.", vim.log.levels.ERROR, { title = "VenvSelect" })
end

return M
