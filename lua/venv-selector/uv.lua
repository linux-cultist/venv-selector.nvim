local M = {}

-- TODO: Uv activation doesnt work well with ordinary venv from cache activation so need to disable that when its a uv venv.
-- Current uv venv is activated from cache even when uv is not installed and no search is running.

M.uv_installed = vim.fn.executable("uv") == 1

--- Check if a file has PEP-723 metadata and auto-activate UV environment if needed
--- @param file_path string The path to the Python file to check
function M.auto_activate_if_needed(file_path)
    local log = require("venv-selector.logger")
    local utils = require("venv-selector.utils")

    if not file_path or file_path == "" or vim.fn.filereadable(file_path) ~= 1 then
        return
    end

    -- Only check Python files
    local filetype = vim.bo[0].filetype
    if filetype ~= "python" then
        return
    end

    -- Check if file has PEP-723 metadata
    if not utils.has_pep723_metadata(file_path) then
        return
    end

    log.debug("Found PEP-723 metadata in: " .. file_path)

    -- Check if we already have a UV environment active for this file
    local path = require("venv-selector.path")
    local current_python = path.current_python_path
    log.debug("Current Python path: " .. (current_python or "nil"))
    if current_python and current_python:match("/environments%-v2/") then
        log.debug("UV environment already active, skipping auto-activation")
        return
    end

    -- Auto-activate UV environment using same approach as manual picker
    log.debug("Starting UV auto-activation for: " .. file_path)
    -- vim.notify("Activating UV environment for script dependencies...", vim.log.levels.INFO, { title = "VenvSelect" })

    M.activate_for_script(file_path)
end

--- Activate UV environment for a specific script file
--- @param script_path string The path to the Python script
function M.activate_for_script(script_path)
    if M.uv_installed == true then
        local log = require("venv-selector.logger")

        -- Use uv python find to get the Python path (same as manual picker)
        local job_id = vim.fn.jobstart({ "uv", "python", "find", "--script", script_path }, {
            stdout_buffered = true,
            on_stdout = function(_, data, _)
                if data and #data > 0 then
                    for _, line in ipairs(data) do
                        if line ~= "" and line:match("python") then
                            local python_path = line:gsub("%s+$", "") -- trim whitespace
                            log.debug("Auto-activating UV environment: " .. python_path)

                            -- Activate the UV environment using the same flow as manual picker
                            local venv = require("venv-selector.venv")
                            venv.activate(python_path, "uv", false)
                            -- vim.notify("UV environment activated automatically", vim.log.levels.INFO,
                            --     { title = "VenvSelect" })
                            break
                        end
                    end
                end
            end,
            on_exit = function(_, exit_code)
                if exit_code ~= 0 then
                    log.debug("UV auto-activation failed with exit code: " .. exit_code)
                    -- vim.notify("UV environment auto-activation failed", vim.log.levels.WARN, { title = "VenvSelect" })
                end
            end
        })

        log.debug("UV jobstart returned job_id: " .. (job_id or "nil"))
    end
end

--- Set up UV environment for activation (called from venv.lua when activating UV type)
--- @param current_file string The current file path
--- @param python_path string The Python path being activated
--- @param on_complete function Optional callback when setup is complete
function M.setup_environment(current_file, python_path, on_complete)
    local log = require("venv-selector.logger")

    if not current_file or current_file == "" then
        log.debug("No current file provided for UV environment setup")
        if on_complete then on_complete(false) end
        return
    end

    log.debug("Setting up UV environment for: " .. current_file)

    -- Run UV sync in background to ensure dependencies are available
    vim.fn.jobstart({ "uv", "sync", "--script", current_file }, {
        stdout_buffered = true,
        on_stdout = function(_, data, _)
            if data and #data > 0 then
                for _, line in ipairs(data) do
                    log.debug("UV sync output: " .. line)
                    if line:match("Using script environment at:") then
                        local env_path = line:match("Using script environment at: (.+)")
                        if env_path then
                            local actual_python_path = env_path .. "/bin/python"
                            log.debug("Found actual UV environment path: " .. actual_python_path)

                            -- Update paths with the correct environment Python
                            local path = require("venv-selector.path")
                            path.current_python_path = actual_python_path
                            path.current_venv_path = path.get_base(actual_python_path)
                            -- Update PATH with the actual environment
                            path.add(path.get_base(actual_python_path))

                            -- vim.notify("UV environment ready with dependencies", vim.log.levels.INFO,
                            -- { title = "VenvSelect" })
                            if on_complete then on_complete(true) end
                            return
                        end
                    end
                end
            end
        end,
        on_exit = function(_, exit_code)
            log.debug("UV sync completed with exit code: " .. exit_code)
            if exit_code ~= 0 then
                log.debug("UV environment setup failed")
                vim.notify("UV dependency sync failed", vim.log.levels.WARN, { title = "VenvSelect" })
                if on_complete then on_complete(false) end
            else
                -- If sync succeeded but we didn't get environment path from output,
                -- we'll use the original python_path as fallback
                log.debug("UV sync succeeded, using provided Python path")
                if on_complete then on_complete(true) end
            end
        end
    })
end

--- Set up auto-activation for PEP-723 files
function M.setup_auto_activation()
    if M.uv_installed == true then
        vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
            pattern = "*.py",
            callback = function()
                -- Use a small delay to ensure the file is fully loaded
                vim.defer_fn(function()
                    local current_file = vim.fn.expand("%:p")
                    M.auto_activate_if_needed(current_file)
                end, 100)
            end,
            group = vim.api.nvim_create_augroup("VenvSelectorUVAuto", { clear = true })
        })
    end
end

return M
