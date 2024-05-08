local gui = require 'venv-selector.gui'
local workspace = require 'venv-selector.workspace'
local path = require("venv-selector.path")
local utils = require("venv-selector.utils")

local function contains_workspace(str)
    return string.find(str, "%$WORKSPACE") ~= nil
end

local function table_empty(t)
    return next(t) == nil
end


local M = {}

local function convert_for_gui(nested_tbl)
    local transformed_table = {}
    local seen = {} -- Table to keep track of items already added

    for _, sublist in pairs(nested_tbl) do
        for _, rv in ipairs(sublist) do
            if rv.name ~= "" and not seen[rv.path] then -- Check if the path has not been added yet
                seen[rv.path] = true                    -- Mark this path as seen
                table.insert(transformed_table, {
                    icon = "",
                    name = rv.name,
                    path = rv.path
                })
            end
        end
    end
    return transformed_table
end


local function set_interactive_search(opts)
    if #opts.args > 0 then
        local settings = {
            search = {
                interactive = {
                    command = opts.args:gsub("%$CWD", vim.fn.getcwd())
                }
            }
        }
        dbg(settings)
        return settings
    end

    return nil
end

local function run_search(opts, user_settings)
    dbg("Starting new search with these settings:")
    --dbg(user_settings, "user_settings")
    --dbg(opts.args, "opts.args")

    local s = {}
    local workspace_folders = workspace.list_folders()
    local job_count = 0
    local results = {}
    local search_settings = set_interactive_search(opts) or user_settings
    local cwd = vim.fn.getcwd()
    --local search_settings = user_settings
    dbg(search_settings, "merged search settings")

    local function on_event(job_id, data, event)
        local job_name = s[job_id].name
        local callback = s[job_id].on_result_callback or utils.try(search_settings, "options", "on_result_callback")

        if event == 'stdout' and data then
            if not results[job_id] then results[job_id] = {} end
            for _, line in ipairs(data) do
                line = path.normalize(line)
                local rv = {}
                rv.path = line
                rv.name = line
                if callback then
                    rv.name = callback(line)
                end
                if line ~= "" and line ~= nil then
                    dbg("Result: " .. rv.path)
                    table.insert(results[job_id], rv)
                end
            end
        elseif event == 'stderr' and data then
            if data and #data > 0 then
                for _, line in ipairs(data) do
                    if line ~= "" then
                        dbg(vim.inspect(line))
                    end
                end
            end
        elseif event == 'exit' then
            job_count = job_count - 1
            if job_count == 0 then
                gui.show(convert_for_gui(results), user_settings)
            end
        end
    end

    local function start_search_job(search, count)
        local job = path.expand(search.command)
        dbg(job, "Starting job")

        local job_id = vim.fn.jobstart(job, {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = on_event,
            on_stderr = on_event,
            on_exit = on_event,
        })

        s[job_id] = search
        count = count + 1
        return count
    end


    -- Start search jobs from config
    for _, search in pairs(search_settings.search) do
        -- Dont start jobs that search $WORKSPACE folders unless the lsp has discovered workspace folders
        if contains_workspace(search.command) == false then
            search.command = search.command:gsub("$CWD", cwd)
            job_count = start_search_job(search, job_count)
        else
            if table_empty(workspace_folders) == false then
                for _, workspace_path in pairs(workspace_folders) do
                    search.command = search.command:gsub("$WORKSPACE_PATH", workspace_path)
                    job_count = start_search_job(search, job_count)
                end
            end
        end
    end

    --utils.print_table(search_settings)
end

function M.New(opts, settings)
    run_search(opts, settings)
end

return M
