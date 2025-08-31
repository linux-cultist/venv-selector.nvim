local workspace = require("venv-selector.workspace")
local path = require("venv-selector.path")
local utils = require("venv-selector.utils")
local log = require("venv-selector.logger")


local M = {}

-- Get current file path with fallback to alternate buffer
local function get_current_file()
    local current_file = vim.fn.expand("%:p")
    log.debug("Initial current_file from expand: '" .. current_file .. "'")

    if current_file == "" then
        local alt_file = vim.fn.expand("#:p")
        if alt_file and alt_file ~= "" then
            current_file = alt_file
            log.debug("Using alternate buffer: " .. current_file)
        end
    end

    log.debug("Final current_file: '" .. current_file .. "'")
    return current_file
end

-- Disable default searches that user has overridden
local function disable_default_searches(search_settings)
    local default_searches = require("venv-selector.config").default_settings.search
    for search_name, _ in pairs(search_settings.search) do
        if default_searches[search_name] ~= nil then
            log.debug("Disabling default search for '" .. search_name .. '"')
            search_settings.search[search_name] = nil
        end
    end
end

-- Handle interactive search from command args
local function set_interactive_search(opts)
    if opts ~= nil and #opts.args > 0 then
        local settings = {
            search = {
                interactive = {
                    command = opts.args:gsub("$CWD", vim.fn.getcwd()),
                },
            },
        }
        log.debug("Interactive search replaces previous search settings: ", settings)
        return settings
    end
    return nil
end

-- Create result entry from search output line
local function create_result_entry(line, search_config, context, callback)
    local rv = {
        path = line,
        name = line,
        icon = context.options.icon or "",
        type = search_config.type or "venv",
        source = search_config.name
    }

    if callback then
        log.debug("Calling on_telescope_result() callback function with line '" ..
            line .. "' and source '" .. rv.source .. "'")
        rv.name = callback(line, rv.source)
    end

    -- Create concise log message
    local log_msg = "Found " .. rv.type .. " from " .. rv.source .. ": " .. rv.name
    if rv.path ~= rv.name then
        log_msg = log_msg .. " (path: " .. rv.path .. ")"
    end
    log.debug(log_msg)
    return rv
end

-- Handle job events (stdout, stderr, exit)
local function handle_job_event(job_id, data, event, context)
    local search_config = context.jobs[job_id]
    if not search_config then return end

    if event == "stdout" and data then
        local callback = search_config.on_telescope_result_callback
            or context.options.on_telescope_result_callback
            or search_config.on_fd_result_callback
            or context.options.on_fd_result_callback

        for _, line in ipairs(data) do
            if line ~= "" and line ~= nil then
                local result = create_result_entry(line, search_config, context, callback)
                context.picker:insert_result(result)
            end
        end
    elseif event == "stderr" and data then
        -- Collect stderr output for error reporting
        if not search_config.stderr_output then
            search_config.stderr_output = {}
        end
        for _, line in ipairs(data) do
            if line ~= "" then
                table.insert(search_config.stderr_output, line)
            end
        end
    elseif event == "exit" then
        -- Log job completion status
        local exit_code = data
        local has_errors = search_config.stderr_output and #search_config.stderr_output > 0
        
        if exit_code == 0 and not has_errors then
            log.debug("Search job '" .. search_config.name .. "' completed successfully")
        else
            local error_msg = "Search job '" .. search_config.name .. "' failed with exit code " .. exit_code
            if has_errors then
                error_msg = error_msg .. ". Error output: " .. table.concat(search_config.stderr_output, " ")
            end
            log.debug(error_msg)
        end
        return true -- Signal that job finished
    end

    return false
end

-- Create job timeout handler
local function create_timeout_handler(job_id, job_name, search_timeout)
    local function stop_job()
        local running = vim.fn.jobwait({ job_id }, 0)[1] == -1
        if running then
            vim.fn.jobstop(job_id)
            local message = "Search with name '" .. job_name ..
                "' took more than " .. search_timeout ..
                " seconds and was stopped. Avoid using VenvSelect in your $HOME directory since it searches all hidden files by default."
            log.warning(message)
            vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
        end
    end

    local timer = vim.uv.new_timer()
    timer:start(search_timeout * 1000, 0, vim.schedule_wrap(function()
        stop_job()
        timer:stop()
        timer:close()
    end))

    return timer
end

-- Start a single search job
local function start_search_job(search_name, search_config, context)
    local job = path.expand(search_config.execute_command)
    -- log.debug("Starting '" .. search_name .. "': '" .. job .. "'")

    -- Handle Windows command splitting
    if vim.uv.os_uname().sysname == "Windows_NT" then
        job = utils.split_cmd_for_windows(job)
    end

    local function job_event_handler(id, data, event)
        handle_job_event(id, data, event, context)
    end

    local job_id = vim.fn.jobstart(job, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = job_event_handler,
        on_stderr = job_event_handler,
        on_exit = function(id, data, event)
            if handle_job_event(id, data, event, context) then
                context.job_count = context.job_count - 1
                if context.job_count == 0 then
                    log.info("Searching finished.")
                    context.picker:search_done()
                    M.search_in_progress = false
                end
            end
        end,
    })

    search_config.name = search_name
    context.jobs[job_id] = search_config
    context.job_count = context.job_count + 1

    -- Set up timeout handler
    create_timeout_handler(job_id, search_name, context.options.search_timeout)

    return context.job_count
end

-- Process workspace-based searches
local function process_workspace_searches(search_name, search_config, context)
    local workspace_folders = workspace.list_folders()
    for _, workspace_path in pairs(workspace_folders) do
        local workspace_search = vim.deepcopy(search_config)
        workspace_search.execute_command = workspace_search.execute_command:gsub("$WORKSPACE_PATH", workspace_path)
        start_search_job(search_name, workspace_search, context)
    end
end

-- Process different types of searches based on their patterns
local function process_search_by_type(search_name, search_config, context)
    -- Handle $FD substitution for all searches
    search_config.execute_command = search_config.command:gsub("$FD", context.options.fd_binary_name)

    log.debug("Processing search: '" ..
        search_name .. "' with command after substitutions: '" .. search_config.execute_command .. "'")

    if search_config.command:find("$WORKSPACE_PATH") then
        process_workspace_searches(search_name, search_config, context)
    elseif search_config.command:find("$CWD") then
        search_config.execute_command = search_config.execute_command:gsub("$CWD", vim.fn.getcwd())
        start_search_job(search_name, search_config, context)
    elseif search_config.command:find("$FILE_DIR") then
        local current_dir = path.get_current_file_directory()
        if current_dir ~= nil then
            search_config.execute_command = search_config.execute_command:gsub("$FILE_DIR", current_dir)
            start_search_job(search_name, search_config, context)
        end
    elseif search_config.command:find("$CURRENT_FILE") then
        local current_file = get_current_file()
        log.debug("Found $CURRENT_FILE search: '" .. search_name .. "', current_file: '" .. current_file .. "'")
        if current_file ~= "" then
            search_config.execute_command = search_config.execute_command:gsub("$CURRENT_FILE", current_file)
            log.debug("Executing $CURRENT_FILE search command")
            start_search_job(search_name, search_config, context)
        else
            log.debug("Skipping $CURRENT_FILE search - current_file is empty")
        end
    else
        start_search_job(search_name, search_config, context)
    end
end

-- Main search function
function M.run_search(picker, opts)
    local user_settings = require("venv-selector.config").user_settings
    local options = user_settings.options

    if M.search_in_progress == true then
        log.info("Not starting new search because previous search is still running.")
        return
    end

    M.search_in_progress = true

    local search_settings = set_interactive_search(opts) or user_settings

    if options.enable_default_searches == false then
        disable_default_searches(search_settings)
    end

    -- Create search context object
    local context = {
        jobs = {},     -- Job tracking dictionary - needed for storing job info by job_id
        job_count = 0, -- Simple counter for active jobs
        picker = picker,
        options = options
    }

    -- Process all searches
    for search_name, search_config in pairs(search_settings.search) do
        if search_config ~= false then
            process_search_by_type(search_name, search_config, context)
        end
    end
end

return M
