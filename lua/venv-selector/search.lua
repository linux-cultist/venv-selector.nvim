local utils = require 'venv-selector.utils'
local gui = require 'venv-selector.gui'
local workspace = require 'venv-selector.workspace'

local M = {}

local function convert_for_gui(nested_tbl)
    local transformed_table = {}
    for _, sublist in pairs(nested_tbl) do
        for _, path in ipairs(sublist) do
            if path ~= "" then -- Skip empty strings
                -- Remove '/bin/python' from the path to get the environment root
                local env_path = path:gsub("/bin/python", "")
                table.insert(transformed_table, {
                    icon = "",
                    path = env_path,
                    source = "Search"
                })
            end
        end
    end
    return transformed_table
end

local function set_interactive_search(args)
    if #args > 0 then
        return {
            search = {
                {
                    name = "Interactive",
                    command = args
                }
            }
        }
    end

    return nil
end

local function run_search(opts, settings)
    local jobs = {}
    local job_count = 0
    local results = {}
    local search_settings = set_interactive_search(opts.args) or settings

    local function on_event(job_id, data, event)
        local job_name = jobs[job_id]
        if event == 'stdout' and data then
            if not results[job_id] then results[job_id] = {} end
            for _, line in ipairs(data) do
                table.insert(results[job_id], line)
            end
        elseif event == 'stderr' and data then
            if data and #data > 0 then
                for _, line in ipairs(data) do
                    if line ~= "" then
                        print("Error from job " .. job_name .. " : " .. vim.inspect(line))
                    end
                end
            end
        elseif event == 'exit' then
            job_count = job_count - 1
            if job_count == 0 then
                for id, lines in pairs(results) do
                    print("Results from " .. jobs[id] .. ":")
                    for _, line in ipairs(lines) do
                        print(line)
                    end
                end

                gui.show(convert_for_gui(results))
            end
        end
    end

    -- Start each job
    for _, search in ipairs(search_settings.search) do
        local job_id = vim.fn.jobstart(utils.expand_home_path(search.command), {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = on_event,
            on_stderr = on_event,
            on_exit = on_event,
        })

        jobs[job_id] = search.name
        job_count = job_count + 1
    end
end

function M.New(opts, settings)
    --utils.printTable(settings)
    run_search(opts, settings)
    -- TODO: How to do with lsp workspace? Should we call the user once per workspace found to let him define a search to run?
    -- TODO: Because he may want to specify what to look for in a workspace.
    utils.printTable(workspace.list_folders())
end

return M
