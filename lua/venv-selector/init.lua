local log = require("venv-selector.logger")
local user_commands = require("venv-selector.user_commands")
local config = require("venv-selector.config")
local venv = require("venv-selector.venv")
local path = require("venv-selector.path")
local ws = require("venv-selector.workspace")

local function on_lsp_attach()
    if vim.bo.filetype == "python" then
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
    return path.current_python_path
end

function M.venv()
    return path.current_venv_path
end

function M.source()
    return venv.current_source
end

function M.workspace_paths()
    return ws.list_folders()
end

function M.cwd()
    return vim.fn.getcwd()
end

function M.file_dir()
    return path.get_current_file_directory()
end

function M.stop_lsp_servers()
    venv.stop_lsp_servers()
end

function M.activate_from_path(python_path)
    venv.activate(python_path, "activate_from_path", true)
end

-- Temporary, will be removed later.
function M.split_command(str)
    local ut = require("venv-selector.utils")
    return ut.split_cmd_for_windows(str)
end

function M.deactivate()
    path.remove_current()
    venv.unset_env_variables()
end

function M.setup(plugin_settings)
    config.merge_user_settings(plugin_settings or {})
    vim.api.nvim_command("hi VenvSelectActiveVenv guifg=" .. config.user_settings.options.telescope_active_venv_color)
    if config.user_settings.options.debug == true then
        log.enabled = true
    end
    user_commands.register()
end

return M
