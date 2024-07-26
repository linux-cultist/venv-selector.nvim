local gui = require("venv-selector.gui")
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
    if opts ~= nil and #opts.fargs > 0 then
        for index, value in ipairs(opts.fargs) do
            if value == "$CWD" then
                opts.fargs[index] = vim.fn.getcwd()
            end
        end
        local settings = {
            search = {
                interactive = {
                    command = opts.fargs,
                },
            },
        }
        log.debug("Interactive search replaces previous search settings: ", settings)
        return settings
    end

    return nil
end

local function run_search(opts)
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

                    gui.insert_result(rv)
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
                gui.remove_dups()
                gui.sort_results()
                gui.update_results()
                M.search_in_progress = false
            end
        end
    end

    local uv = vim.loop
    local function start_search_job(job_name, search, count)
        if type(search.command) == "table" then
            log.debug("Starting '" .. job_name .. "': '" .. table.concat(search.execute_command, " ") .. "'")
        else
            search.execute_command = path.expand(search.execute_command)
            log.debug("Starting '" .. job_name .. "': '" .. search.execute_command .. "'")
        end
        M.search_in_progress = true
        local job_id = vim.fn.jobstart(search.execute_command, {
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
            if type(search.command) == "table" then
                search.execute_command = vim.deepcopy(search.command)
                if search.command[1] == "$FD" then
                    search.execute_command[1] = options.fd_binary_name
                end

                local should_start = true
                for index, value in ipairs(search.command) do
                    -- search has $WORKSPACE_PATH inside - dont start it unless the lsp has discovered workspace folders
                    if value == "$WORKSPACE_PATH" then
                        local workspace_folders = workspace.list_folders()
                        if #workspace_folders > 0 then
                            table.remove(search.execute_command, index)
                            for _, workspace_path in pairs(workspace_folders) do
                                table.insert(search.execute_command, index, workspace_path)
                            end
                        else
                            should_start = false
                            break
                        end
                    -- search has $CWD inside
                    elseif value == "$CWD" then
                        search.execute_command[index] = cwd
                    -- search has $FILE_DIR inside
                    elseif value == "$FILE_DIR" then
                        if current_dir ~= nil then
                            search.execute_command[index] = current_dir
                        else
                            should_start = false
                            break
                        end
                    end
                    search.execute_command[index] = path.expand(search.execute_command[index])
                end
                if should_start then
                    job_count = start_search_job(job_name, search, job_count)
                end
            else
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
end

function M.New(opts)
    local options = require("venv-selector.config").user_settings.options
    if options.fd_binary_name == nil then
        local message =
            "Cannot find any fd binary on your system. If its installed under a different name, you can set options.fd_binary_name to its name."
        log.error(message)
        vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
    elseif utils.check_dependencies_installed() == false then
        local message = "Not all required modules are installed."
        log.error(message)
        vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
    elseif utils.table_has_content(gui.results) == false then
        run_search(opts)
    else
    end
end

return M
