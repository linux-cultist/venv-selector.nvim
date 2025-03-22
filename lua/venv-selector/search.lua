local workspace = require("venv-selector.workspace")
local path = require("venv-selector.path")
local utils = require("venv-selector.utils")
local log = require("venv-selector.logger")

local function is_workspace_search(str)
    return string.find(str, "$WORKSPACE_PATH") ~= nil
end

local function is_cwd_search(str)
    return string.find(str, "$CWD") ~= nil
end

local function is_filepath_search(str)
    return string.find(str, "$FILE_DIR") ~= nil
end

local M = {}

local function disable_default_searches(search_settings)
    local default_searches = require("venv-selector.config").default_settings.search
    for search_name, _ in pairs(search_settings.search) do
        if default_searches[search_name] ~= nil then
            log.debug("Disabling default search for '" .. search_name .. '"')
            search_settings.search[search_name] = nil
        end
    end
end

local function set_interactive_search(opts)
    if opts ~= nil and #opts.args > 0 then
        local settings = {
            search = {
                interactive = {
                    command = opts.args:gsub("%$CWD", vim.fn.getcwd()),
                },
            },
        }
        log.debug("Interactive search replaces previous search settings: ", settings)
        return settings
    end

    return nil
end

function M.run_search(picker, opts)
    local user_settings = require("venv-selector.config").user_settings
    local options = require("venv-selector.config").user_settings.options

    if M.search_in_progress == true then
        log.info("Not starting new search because previous search is still running.")
        return
    end

    local jobs = {}
    local job_count = 0
    local results = {}
    local search_settings = set_interactive_search(opts) or user_settings
    local cwd = vim.fn.getcwd()

    local search_timeout = options.search_timeout

    local function on_event(job_id, data, event)
        local callback = jobs[job_id].on_telescope_result_callback
            or utils.try(search_settings, "options", "on_telescope_result_callback")

        if event == "stdout" and data then
            local search = jobs[job_id]

            if not results[job_id] then
                results[job_id] = {}
            end
            for _, line in ipairs(data) do
                if line ~= "" and line ~= nil then
                    local rv = {}
                    rv.path = line
                    rv.name = line
                    rv.icon = ""
                    rv.type = search.type or "venv"
                    rv.source = search.name

                    if callback then
                        log.debug(
                            "Calling on_telescope_result() callback function with line '"
                                .. line
                                .. "' and source '"
                                .. rv.source
                                .. "'"
                        )
                        rv.name = callback(line, rv.source)
                    end

                    log.debug("Result:")
                    log.debug(rv)
                    picker:insert_result(rv)
                end
            end
        elseif event == "stderr" and data then
            if data and #data > 0 then
                for _, line in ipairs(data) do
                    if line ~= "" then
                        log.debug(line)
                    end
                end
            end
        elseif event == "exit" then
            job_count = job_count - 1
            if job_count == 0 then
                log.info("Searching finished.")
                picker:search_done()
                M.search_in_progress = false
            end
        end
    end

    local uv = vim.loop
    local function start_search_job(job_name, search, count)
        local job = path.expand(search.execute_command)

        log.debug("Starting '" .. job_name .. "': '" .. job .. "'")
        M.search_in_progress = true

        -- Special for windows to run the command without a shell (translate the command to a lua table before sending to jobstart)
        if vim.loop.os_uname().sysname == "Windows_NT" then
            job = utils.split_cmd_for_windows(job)
        end

        local job_id = vim.fn.jobstart(job, {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = on_event,
            on_stderr = on_event,
            on_exit = on_event,
        })
        search.name = job_name
        jobs[job_id] = search
        count = count + 1

        local function stop_job()
            local running = vim.fn.jobwait({ job_id }, 0)[1] == -1
            if running then
                vim.fn.jobstop(job_id)
                local message = "Search with name '"
                    .. jobs[job_id].name
                    .. "' took more than "
                    .. search_timeout
                    .. " seconds and was stopped. Avoid using VenvSelect in your $HOME directory since it searches all hidden files by default."
                log.warning(message)
                vim.notify(message, vim.log.levels.ERROR, {
                    title = "VenvSelect",
                })
            end
        end

        -- Start a timer to terminate the job after 5 seconds
        local timer = uv.new_timer()
        timer:start(
            search_timeout * 1000,
            0,
            vim.schedule_wrap(function()
                stop_job()
                timer:stop()
                timer:close()
            end)
        )

        return count
    end

    if options.enable_default_searches == false then
        disable_default_searches(search_settings)
    end

    local current_dir = path.get_current_file_directory()

    -- Start search jobs from config
    for job_name, search in pairs(search_settings.search) do
        if search ~= false then -- Can be set to false by user to not search path
            search.execute_command = search.command:gsub("$FD", options.fd_binary_name)

            -- search has $WORKSPACE_PATH inside - dont start it unless the lsp has discovered workspace folders
            if is_workspace_search(search.command) then
                local workspace_folders = workspace.list_folders()
                for _, workspace_path in pairs(workspace_folders) do
                    search.execute_command = search.execute_command:gsub("$WORKSPACE_PATH", workspace_path)
                    job_count = start_search_job(job_name, search, job_count)
                end
                -- search has $CWD inside
            elseif is_cwd_search(search.command) then
                search.execute_command = search.execute_command:gsub("$CWD", cwd)
                job_count = start_search_job(job_name, search, job_count)
                -- search has $FILE_DIR inside
            elseif is_filepath_search(search.command) then
                if current_dir ~= nil then
                    search.execute_command = search.execute_command:gsub("$FILE_DIR", current_dir)
                    job_count = start_search_job(job_name, search, job_count)
                end
            else
                -- search has no keywords inside
                job_count = start_search_job(job_name, search, job_count)
            end
        end
    end
end

return M
