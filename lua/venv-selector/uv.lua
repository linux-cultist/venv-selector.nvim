local M = {}

M.uv_installed = vim.fn.executable("uv") == 1

-- Track recently activated files to prevent duplicates
local recently_activated = {}

--- Helper function to handle jobstart data output
--- @param data table The data array from jobstart callback
--- @param output_lines table Array to store output lines
--- @param log_prefix string Prefix for log messages
--- @param command_name string Name of command for logging
local function handle_data(data, output_lines, log_prefix, command_name)
    local log = require("venv-selector.logger")
    if data and #data > 0 then
        for _, line in ipairs(data) do
            if line ~= "" then
                log.debug(command_name .. " " .. log_prefix .. ": " .. line)
                table.insert(output_lines, line)
            end
        end
    end
end

--- Execute a UV command with standardized error handling
--- @param cmd table The UV command to execute (e.g., {"uv", "sync", "--script", "file.py"})
--- @param callback function Called with (success, stdout_lines, stderr_lines, exit_code)
local function run_uv_command(cmd, callback)
    local log = require("venv-selector.logger")
    local command_name = table.concat(cmd, " ")
    local stdout_lines = {}
    local stderr_lines = {}
    
    log.debug("Running UV command: " .. vim.inspect(cmd))
    
    return vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data, _)
            handle_data(data, stdout_lines, "stdout", command_name)
        end,
        on_stderr = function(_, data, _)
            handle_data(data, stderr_lines, "stderr", command_name)
        end,
        on_exit = function(_, exit_code)
            log.debug(command_name .. " completed with exit code: " .. exit_code)
            
            local success = exit_code == 0
            if not success then
                for _, stderr_line in ipairs(stderr_lines) do
                    vim.notify(stderr_line, vim.log.levels.ERROR, { title = "VenvSelect" })
                end
            end
            
            if callback then
                callback(success, stdout_lines, stderr_lines, exit_code)
            end
        end
    })
end

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

    -- Skip if we recently activated this file (within 1 second)
    local now = vim.loop.now()
    if recently_activated[file_path] and (now - recently_activated[file_path]) < 1000 then
        log.debug("Skipping activation - recently activated: " .. file_path)
        return
    end

    log.debug("Found PEP-723 metadata in: " .. file_path)

    -- Check if we already have the correct UV environment active for this specific file
    local path = require("venv-selector.path")
    local current_python = path.current_python_path
    log.debug("Current Python path: " .. (current_python or "nil"))

    -- If we have a UV environment active, check if it's the right one for this file
    if current_python and current_python:match("/environments%-v2/") then
        -- Get the expected Python path for this file to compare
        M.check_and_activate_if_different(file_path, current_python)
        return
    end

    -- No UV environment active, so activate one for this file
    log.debug("Starting UV auto-activation for: " .. file_path)
    recently_activated[file_path] = now
    M.activate_for_script(file_path)
end

--- Check if current UV environment matches the file and activate different one if needed
--- @param script_path string The path to the Python script
--- @param current_python_path string The currently active Python path
function M.check_and_activate_if_different(script_path, current_python_path)
    if M.uv_installed == true then
        local log = require("venv-selector.logger")

        -- Get the expected Python path for this script
        run_uv_command({ "uv", "python", "find", "--script", script_path }, function(success, stdout_lines, stderr_lines, exit_code)
            if not success then
                log.debug("UV environment check failed with exit code: " .. exit_code)
                return
            end
            
            -- Find the Python path from stdout
            for _, line in ipairs(stdout_lines) do
                if line:match("python") then
                    local expected_python = line:gsub("%s+$", "") -- trim whitespace
                    log.debug("Expected Python for " .. script_path .. ": " .. expected_python)
                    log.debug("Current Python: " .. current_python_path)

                    -- Always sync when metadata files change (handles dependency updates)
                    if expected_python ~= current_python_path then
                        log.debug("Switching UV environment from " ..
                            current_python_path .. " to " .. expected_python)
                        local venv = require("venv-selector.venv")
                        venv.activate(expected_python, "uv", false)
                    else
                        log.debug("UV environment path correct, but syncing dependencies")
                        -- Run uv sync to ensure dependencies are up to date
                        run_uv_command({ "uv", "sync", "--script", script_path }, function(sync_success, _, _, sync_exit_code)
                            if sync_success then
                                log.debug("UV sync completed successfully")
                            else
                                log.debug("UV sync failed with exit code: " .. sync_exit_code)
                            end
                        end)
                    end
                    break
                end
            end
        end)


    else
        require("venv-selector.logger").debug("Uv not found on system.")
    end
end

--- Activate UV environment for a specific script file
--- @param script_path string The path to the Python script
function M.activate_for_script(script_path)
    if M.uv_installed == true then
        local log = require("venv-selector.logger")

        -- First check what environment this script needs
        log.debug("Running UV command: " .. vim.inspect({ "uv", "python", "find", "--script", script_path }))

        run_uv_command({ "uv", "python", "find", "--script", script_path }, function(success, stdout_lines, stderr_lines, exit_code)
            if not success then
                log.debug("UV auto-activation failed with exit code: " .. exit_code)
                -- Show stderr errors (but run_uv_command already handles this)
                return
            end
            
            -- Find the Python path from stdout
            for _, line in ipairs(stdout_lines) do
                if line:match("python") then
                    local expected_python = line:gsub("%s+$", "") -- trim whitespace
                    local path = require("venv-selector.path")
                    local current_python = path.current_python_path

                    log.debug("Expected Python for " .. script_path .. ": " .. expected_python)
                    log.debug("Current Python: " .. (current_python or "nil"))

                    -- If we already have the correct environment, don't run setup again
                    if current_python == expected_python then
                        log.debug("UV environment already correct for this file")
                        return
                    end

                    log.debug("Auto-activating UV environment: " .. expected_python)

                    -- Only run setup if we need a different environment
                    M.setup_environment(script_path, nil, function(setup_success)
                        if setup_success then
                            local venv = require("venv-selector.venv")
                            -- Skip UV setup in venv.activate since we already did it
                            venv.activate(expected_python, "uv_skip_setup", false)
                            -- vim.notify("UV environment activated automatically", vim.log.levels.INFO,
                            --     { title = "VenvSelect" })
                        else
                            log.debug("UV environment setup failed, cannot activate")
                        end
                    end)
                    break
                end
            end
        end)

    else
        require("venv-selector.logger").debug("Uv not found on system.")
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
    run_uv_command({ "uv", "sync", "--script", current_file }, function(success, stdout_lines, stderr_lines, exit_code)
        if not success then
            log.debug("UV environment setup failed")
            vim.notify("UV dependency sync failed", vim.log.levels.ERROR, { title = "VenvSelect" })
            if on_complete then on_complete(false) end
            return
        end
        
        -- Look for environment path in stdout
        for _, line in ipairs(stdout_lines) do
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
        
        -- If sync succeeded but we didn't get environment path from output,
        -- we'll use the original python_path as fallback
        log.debug("UV sync succeeded, using provided Python path")
        if on_complete then on_complete(true) end
    end)
end

--- Set up auto-activation for PEP-723 files
function M.setup_auto_activation()
    if M.uv_installed == true then
        -- Handle opening files (existing or new)
        vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
            pattern = "*.py",
            callback = function()
                -- Use longer delay to let LSP attach and cache check complete first
                vim.defer_fn(function()
                    local current_file = vim.fn.expand("%:p")
                    M.auto_activate_if_needed(current_file)
                end, 300)
            end,
            group = vim.api.nvim_create_augroup("VenvSelectorUVOpen", { clear = true })
        })

        -- Handle switching between already-loaded buffers
        vim.api.nvim_create_autocmd({"BufEnter", "BufWrite"}, {
            pattern = "*.py",
            callback = function()
                -- Only activate after a short delay to avoid initial file open conflicts
                vim.defer_fn(function()
                    local current_file = vim.fn.expand("%:p")
                    M.auto_activate_if_needed(current_file)
                end, 500)
            end,
            group = vim.api.nvim_create_augroup("VenvSelectorUVSwitch", { clear = true })
        })
    end
end

return M
