-- local log = require("venv-selector.logger")
-- local user_commands = require("venv-selector.user_commands")
-- local config = require("venv-selector.config")
-- local venv = require("venv-selector.venv")
-- local path = require("venv-selector.path")
-- local ws = require("venv-selector.workspace")

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

-- Temporary, will be removed later.
function M.split_command(str)
    local ut = require("venv-selector.utils")
    return ut.split_cmd_for_windows(str)
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

-- Auto-activate UV environment for PEP-723 scripts
local function auto_activate_uv_if_needed()
    local utils = require("venv-selector.utils")
    local log = require("venv-selector.logger")
    local path = require("venv-selector.path")
    local venv = require("venv-selector.venv")

    local current_file = vim.fn.expand("%:p")
    if current_file == "" or vim.fn.filereadable(current_file) ~= 1 then
        return
    end

    -- Only check Python files
    local filetype = vim.api.nvim_buf_get_option(0, 'filetype')
    if filetype ~= "python" then
        return
    end

    -- Check if file has PEP-723 metadata
    if not utils.has_pep723_metadata(current_file) then
        return
    end

    log.debug("Found PEP-723 metadata in: " .. current_file)

    -- Check if we already have a UV environment active for this file
    local current_python = path.current_python_path
    log.debug("Current Python path: " .. (current_python or "nil"))
    if current_python and current_python:match("/environments%-v2/") then
        log.debug("UV environment already active, skipping auto-activation")
        return
    end

    -- Auto-activate UV environment using same approach as manual picker
    log.debug("Starting UV auto-activation for: " .. current_file)
    vim.notify("Activating UV environment for script dependencies...", vim.log.levels.INFO, { title = "VenvSelect" })

    -- Use uv python find to get the Python path (same as manual picker)
    local job_id = vim.fn.jobstart({ "uv", "python", "find", "--script", current_file }, {
        stdout_buffered = true,
        on_stdout = function(_, data, _)
            if data and #data > 0 then
                for _, line in ipairs(data) do
                    if line ~= "" and line:match("python") then
                        local python_path = line:gsub("%s+$", "") -- trim whitespace
                        log.debug("Auto-activating UV environment: " .. python_path)

                        -- Activate the UV environment using the same flow as manual picker
                        venv.activate(python_path, "uv", false)
                        vim.notify("UV environment activated automatically", vim.log.levels.INFO,
                            { title = "VenvSelect" })
                        break
                    end
                end
            end
        end,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                log.debug("UV auto-activation failed with exit code: " .. exit_code)
                vim.notify("UV environment auto-activation failed", vim.log.levels.WARN, { title = "VenvSelect" })
            end
        end
    })

    log.debug("UV jobstart returned job_id: " .. (job_id or "nil"))
end

-- Set up auto-activation on file open
local function setup_auto_activation()
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
        pattern = "*.py",
        callback = function()
            -- Use a small delay to ensure the file is fully loaded
            vim.defer_fn(auto_activate_uv_if_needed, 100)
        end,
        group = vim.api.nvim_create_augroup("VenvSelectorUVAuto", { clear = true })
    })
end

-- Initialize auto-activation
setup_auto_activation()

return M
