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
            local success = exit_code == 0
            
            if not success then
                log.debug(command_name .. " failed with exit code: " .. exit_code)
                if #stderr_lines > 0 then
                    local error_message = table.concat(stderr_lines, "\n")
                    vim.notify(error_message, vim.log.levels.ERROR, { title = "VenvSelect" })
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

    -- Skip if we recently activated this file (within 100ms) - check early to prevent duplicate work
    local now = vim.loop.now()
    if recently_activated[file_path] and (now - recently_activated[file_path]) < 100 then
        log.debug("Skipping activation - recently activated: " .. file_path)
        return
    end

    -- Check if file has PEP-723 metadata
    if not utils.has_pep723_metadata(file_path) then
        return
    end

    log.debug("Found PEP-723 metadata in: " .. file_path)

    -- Check if we already have the correct UV environment active for this specific file
    local path = require("venv-selector.path")
    local current_python = path.current_python_path
    log.debug("Current Python path: " .. (current_python or "nil"))

    -- Always activate UV environment for PEP-723 files to ensure sync
    recently_activated[file_path] = now
    M.activate_for_script(file_path)
end



--- Activate UV environment for a specific script file
--- @param script_path string The path to the Python script
function M.activate_for_script(script_path)
    if M.uv_installed == true then
        local log = require("venv-selector.logger")

        -- Always run setup to ensure environment and dependencies are up to date
        M.setup_environment(script_path, nil, function(setup_success)
            if setup_success then
                -- Get the actual Python path after setup
                run_uv_command({ "uv", "python", "find", "--script", script_path }, function(find_success, find_stdout_lines, _, _)
                    if find_success then
                        for _, line in ipairs(find_stdout_lines) do
                            if line:match("python") then
                                local expected_python = line:gsub("%s+$", "") -- trim whitespace
                                log.debug("Activating UV environment: " .. expected_python)
                                local venv = require("venv-selector.venv")
                                venv.activate(expected_python, "uv", false)
                                break
                            end
                        end
                    end
                end)
            else
                log.debug("UV environment setup failed, cannot activate")
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
        -- Handle opening/switching files
        vim.api.nvim_create_autocmd({ "BufEnter" }, {
            pattern = "*.py",
            callback = function()
                vim.defer_fn(function()
                    local current_file = vim.fn.expand("%:p")
                    M.auto_activate_if_needed(current_file)
                end, 300)
            end,
            group = vim.api.nvim_create_augroup("VenvSelectorUV", { clear = true })
        })
        
        -- Handle file saves (force recheck since metadata may have changed)
        vim.api.nvim_create_autocmd({ "BufWrite" }, {
            pattern = "*.py",
            callback = function()
                vim.defer_fn(function()
                    local current_file = vim.fn.expand("%:p")
                    -- Clear cache since file content may have changed
                    local utils = require("venv-selector.utils")
                    utils.clear_pep723_cache()
                    M.auto_activate_if_needed(current_file)
                end, 300)
            end,
            group = vim.api.nvim_create_augroup("VenvSelectorUVWrite", { clear = true })
        })
    end
end

return M
