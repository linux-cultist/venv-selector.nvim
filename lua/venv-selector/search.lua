local workspace = require("venv-selector.workspace")
local path = require("venv-selector.path")
local utils = require("venv-selector.utils")
local log = require("venv-selector.logger")

local M = {}

-- Module-level state for tracking active search jobs
M.active_jobs = {}
M.active_job_count = 0

-- Stop all active search jobs
function M.stop_search()
    log.debug("stop_search() called, active jobs: " .. M.active_job_count)

    if M.active_job_count == 0 then
        return
    end

    log.debug("Stopping " .. M.active_job_count .. " active search jobs")

    for job_id, _ in pairs(M.active_jobs) do
        if vim.fn.jobwait({ job_id }, 0)[1] == -1 then
            vim.fn.jobstop(job_id)
        end
    end

    M.active_jobs = {}
    M.active_job_count = 0
    M.search_in_progress = false
end

-- Get current file path with fallback to alternate buffer
local function get_current_file()
    local current_file = vim.fn.expand("%:p")
    if current_file == "" then
        local alt_file = vim.fn.expand("#:p")
        if alt_file and alt_file ~= "" then
            current_file = alt_file
            log.debug("Using alternate buffer: " .. current_file)
        end
    end
    log.debug("Current file: '" .. current_file .. "'")
    return current_file
end

-- Create job event handler with closure over picker/callbacks and options
local function create_job_event_handler(picker, options)
    return function(job_id, data, event)
        local search_config = M.active_jobs[job_id]
        if not search_config then return end

        if event == "stdout" and data then
            local callback = search_config.on_telescope_result_callback
                or options.on_telescope_result_callback
                or search_config.on_fd_result_callback
                or options.on_fd_result_callback

            for _, line in ipairs(data) do
                if line ~= "" then
                    local result = {
                        path = line,
                        name = callback and callback(line, search_config.name) or line,
                        icon = options.icon or "",
                        type = search_config.type or "venv",
                        source = search_config.name
                    }
                    log.debug("Found " .. result.type .. " from " .. result.source .. ": " .. result.name)

                    -- Support both picker object and callback table
                    if picker then
                        if type(picker.insert_result) == "function" then
                            picker:insert_result(result)
                        elseif type(picker.on_result) == "function" then
                            picker.on_result(result)
                        end
                    end
                end
            end
        elseif event == "stderr" and data then
            search_config.stderr_output = search_config.stderr_output or {}
            for _, line in ipairs(data) do
                if line ~= "" then
                    table.insert(search_config.stderr_output, line)
                end
            end
        elseif event == "exit" then
            local exit_code = data
            local has_errors = search_config.stderr_output and #search_config.stderr_output > 0

            if exit_code ~= 0 or has_errors then
                local error_msg = "Search job '" .. search_config.name .. "' failed with exit code " .. exit_code
                if has_errors then
                    error_msg = error_msg .. ". Error: " .. table.concat(search_config.stderr_output, " ")
                end
                log.debug(error_msg)
            else
                log.debug("Search job '" .. search_config.name .. "' completed successfully")
            end

            M.active_job_count = M.active_job_count - 1
            if M.active_job_count == 0 then
                log.info("Searching finished.")

                -- Support both picker object and callback table
                if picker then
                    if type(picker.search_done) == "function" then
                        picker:search_done()
                    elseif type(picker.on_complete) == "function" then
                        picker.on_complete()
                    end
                end

                M.search_in_progress = false
            end
        end
    end
end

-- Start a single search job
local function start_search_job(search_name, search_config, job_event_handler, search_timeout)
    local job = path.expand(search_config.execute_command)

    if vim.uv.os_uname().sysname == "Windows_NT" then
        job = utils.split_cmd_for_windows(job)
    end

    local job_id = vim.fn.jobstart(job, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = job_event_handler,
        on_stderr = job_event_handler,
        on_exit = job_event_handler,
    })

    search_config.name = search_name
    M.active_jobs[job_id] = search_config
    M.active_job_count = M.active_job_count + 1

    -- Set up timeout handler
    local timer = vim.uv.new_timer()
    timer:start(search_timeout * 1000, 0, vim.schedule_wrap(function()
        if vim.fn.jobwait({ job_id }, 0)[1] == -1 then
            vim.fn.jobstop(job_id)
            local msg = "Search '" .. search_name .. "' took more than " .. search_timeout ..
                " seconds and was stopped. Avoid using VenvSelect in $HOME directory."
            log.warning(msg)
            vim.notify(msg, vim.log.levels.ERROR, { title = "VenvSelect" })
        end
        timer:stop()
        timer:close()
    end))
end

-- Process and start searches based on their command patterns
local function process_search(search_name, search_config, job_event_handler, options)
    local cmd = search_config.command:gsub("$FD", options.fd_binary_name)

    log.debug("Processing search: '" .. search_name .. "' with command: '" .. cmd .. "'")

    -- Handle different substitution patterns
    if cmd:find("$WORKSPACE_PATH") then
        for _, workspace_path in pairs(workspace.list_folders()) do
            local ws_search = vim.deepcopy(search_config)
            ws_search.execute_command = cmd:gsub("$WORKSPACE_PATH", workspace_path)
            start_search_job(search_name, ws_search, job_event_handler, options.search_timeout)
        end
    elseif cmd:find("$CWD") then
        search_config.execute_command = cmd:gsub("$CWD", vim.fn.getcwd())
        start_search_job(search_name, search_config, job_event_handler, options.search_timeout)
    elseif cmd:find("$FILE_DIR") then
        local current_dir = path.get_current_file_directory()
        if current_dir then
            search_config.execute_command = cmd:gsub("$FILE_DIR", current_dir)
            start_search_job(search_name, search_config, job_event_handler, options.search_timeout)
        end
    elseif cmd:find("$CURRENT_FILE") then
        local current_file = get_current_file()
        if current_file ~= "" then
            search_config.execute_command = cmd:gsub("$CURRENT_FILE", current_file)
            start_search_job(search_name, search_config, job_event_handler, options.search_timeout)
        else
            log.debug("Skipping $CURRENT_FILE search - current_file is empty")
        end
    else
        search_config.execute_command = cmd
        start_search_job(search_name, search_config, job_event_handler, options.search_timeout)
    end
end

-- Main search function
-- @param picker (optional) Either a picker object with insert_result() and search_done() methods,
--               or a table with on_result(result) and on_complete() callbacks, or nil
-- @param opts Command options for interactive search
function M.run_search(picker, opts)
    -- Stop any previous search before starting a new one
    if M.search_in_progress then
        log.info("Stopping previous search before starting new one.")
        M.stop_search()
    end

    M.search_in_progress = true

    local user_settings = require("venv-selector.config").user_settings
    local options = user_settings.options

    -- Handle interactive search from command args
    local search_settings = user_settings
    if opts and #opts.args > 0 then
        -- Only run the interactive search, ignore all other searches
        ---@diagnostic disable-next-line: missing-fields
        search_settings = {
            search = {
                interactive = {
                    command = opts.args:gsub("$CWD", vim.fn.getcwd()),
                },
            },
        }
        log.debug("Interactive search replaces all previous searches")
    end

    -- Disable default searches that user has overridden
    if not options.enable_default_searches then
        local default_searches = require("venv-selector.config").default_settings.search
        for search_name, _ in pairs(search_settings.search) do
            if default_searches[search_name] then
                log.debug("Disabling default search: '" .. search_name .. "'")
                search_settings.search[search_name] = nil
            end
        end
    end

    -- Reset module-level state and create event handler
    M.active_jobs = {}
    M.active_job_count = 0
    local job_event_handler = create_job_event_handler(picker, options)

    -- Process all searches
    for search_name, search_config in pairs(search_settings.search) do
        if search_config ~= false then
            process_search(search_name, search_config, job_event_handler, options)
        end
    end
end

return M
