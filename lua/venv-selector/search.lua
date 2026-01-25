local workspace = require("venv-selector.workspace")
local path = require("venv-selector.path")
local utils = require("venv-selector.utils")
local log = require("venv-selector.logger")

local M = {}

---@class SearchResult
---@field path string The file path to the virtual environment
---@field name string Display name of the virtual environment
---@field icon string Icon to display
---@field type string Type of environment (e.g., "venv", "conda")
---@field source string Search source that found this result

---@class SearchCallbacks
---@field on_result fun(result: SearchResult) Called for each result found
---@field on_complete fun() Called when search completes

---@class Picker
---@field insert_result fun(self: Picker, result: SearchResult) Add a result to the picker
---@field search_done fun(self: Picker) Called when search completes

---@class SearchOpts
---@field args string Command arguments for interactive search

---@class SearchConfig
---@field command string The search command to execute
---@field type? string The type of virtual environment
---@field on_telescope_result_callback? fun(line: string, source: string): string
---@field on_fd_result_callback? fun(line: string, source: string): string
---@field execute_command? string The expanded command to execute
---@field name? string The name of this search
---@field stderr_output? string[] Collected stderr output

-- Module-level state for tracking active search jobs
---@type table<integer, SearchConfig>
M.active_jobs = {}
---@type integer
M.active_job_count = 0
---@type boolean?
M.search_in_progress = nil

---Stop all active search jobs
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

---Get current file path with fallback to alternate buffer
---@return string current_file The current file path
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

---Create job event handler with closure over picker/callbacks and options
---@param picker Picker|SearchCallbacks|nil Picker object or callbacks
---@param options table Search options
---@return fun(job_id: integer, data: any, event: string) event_handler
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
                        local p = picker
                        if type(p.insert_result) == "function" then
                            ---@cast p Picker
                            p:insert_result(result)
                        elseif type(p.on_result) == "function" then
                            ---@cast p SearchCallbacks
                            p.on_result(result)
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
                    local p = picker
                    if type(p.search_done) == "function" then
                        ---@cast p Picker
                        p:search_done()
                    elseif type(p.on_complete) == "function" then
                        ---@cast p SearchCallbacks
                        p.on_complete()
                    end
                end

                M.search_in_progress = false
            end
        end
    end
end

local function expand_env(s)
    -- expand leading ~ (only when it’s a path prefix)
    s = s:gsub("^~", vim.fn.expand("~"))

    -- $VAR (avoid $$)
    s = s:gsub("%$([%w_]+)", function(k)
        return vim.env[k] or ""
    end)

    return s
end

---Start a single search job
---@param search_name string Name of the search
---@param search_config SearchConfig Search configuration
---@param job_event_handler fun(job_id: integer, data: any, event: string) Job event callback
---@param search_timeout integer Timeout in seconds
local function start_search_job(search_name, search_config, job_event_handler, search_timeout)
    if not search_config.execute_command then
        log.error("No execute_command for search '" .. search_name .. "'")
        return
    end

    local cmd
    -- Don't expand commands, use them directly
    local job = search_config.execute_command
    ---@cast job string
    local options = require("venv-selector.config").get_user_options()

    -- log.debug("Executing search '" ..
    --     search_name .. "' (using " .. options.shell.shell .. " " .. options.shell.shellcmdflag .. "): '" .. job .. "'")

    -- local sysname = vim.uv.os_uname().sysname or "Linux"
    -- if sysname == "Windows_NT" then
    --     cmd = utils.split_cmd_for_windows(job)
    --     if not cmd or #cmd == 0 then
    --         log.error("Failed to split command for Windows. Original: " .. search_config.execute_command)
    --         return
    --     end
    -- else
    --     cmd = { options.shell.shell, options.shell.shellcmdflag, job } -- We use a shell on linux and mac but not windows at the moment.
    -- end
    local expanded_job = expand_env(job)                              -- expands $VAR and ~
    
    log.debug("Executing search '" ..
        search_name .. "' (using " .. options.shell.shell .. " " .. options.shell.shellcmdflag .. "): '" .. expanded_job .. "'")
    
    cmd = { options.shell.shell, options.shell.shellcmdflag, expanded_job } -- We use a shell on linux and mac but not windows at the moment.
    local job_id = vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = job_event_handler,
        on_stderr = job_event_handler,
        on_exit = job_event_handler,
    })

    if job_id <= 0 then
        local err = job_id == 0 and "invalid arguments" or "command not executable"
        log.error("Failed to start job '" .. search_name .. "': " .. err .. ". Command: " .. vim.inspect(job))
        return
    end

    search_config.name = search_name
    M.active_jobs[job_id] = search_config
    M.active_job_count = M.active_job_count + 1

    -- Set up timeout handler
    local timer = vim.uv.new_timer()
    if timer then
        timer:start(search_timeout * 1000, 0, vim.schedule_wrap(function()
            if vim.fn.jobwait({ job_id }, 0)[1] == -1 then
                vim.fn.jobstop(job_id)
                local msg = "Search '" .. search_name .. "' took more than " .. search_timeout ..
                    " seconds and was stopped. Avoid using VenvSelect in $HOME directory."
                log.warning(msg)
                vim.notify(msg, vim.log.levels.ERROR, { title = "VenvSelect" })
            end
            if timer then
                timer:stop()
                timer:close()
            end
        end))
    end
end

---Process and start searches based on their command patterns
---@param search_name string Name of the search
---@param search_config SearchConfig Search configuration
---@param job_event_handler fun(job_id: integer, data: any, event: string) Job event callback
---@param options table Search options
local function process_search(search_name, search_config, job_event_handler, options)
    local cmd = search_config.command:gsub("$FD", options.fd_binary_name)

    -- log.debug("Executing search '" ..
    --     search_name .. "' (using " .. options.shell.shell .. " " .. options.shell.shellcmdflag .. "): '" .. cmd .. "'")

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

---Main search function
---@param picker Picker|SearchCallbacks|nil Either a picker object with insert_result() and search_done() methods, or a table with on_result(result) and on_complete() callbacks, or nil
---@param opts SearchOpts|nil Command options for interactive search
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
        local default_searches = require("venv-selector.config").get_default_searches()
        for search_name, search_config in pairs(search_settings.search) do
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
        if search_config ~= true and search_config ~= false then
            process_search(search_name, search_config, job_event_handler, options)
        end
    end
end

return M
