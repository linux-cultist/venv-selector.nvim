local utils = require 'venv-selector.utils'


local M = {}

function M.convert_for_gui(nested_tbl)
    local transformed_table = {}
    for _, sublist in pairs(nested_tbl) do
        for _, path in ipairs(sublist) do
            if path ~= "" then -- Skip empty strings
                -- Remove '/bin/python' from the path to get the environment root
                local env_path = path:gsub("/bin/python", "")
                -- Add transformed data to the new table
                table.insert(transformed_table, {
                    icon = "", -- Set default icon
                    path = env_path,
                    source = "Search" -- Optional, if you want to include a source or any other additional info
                })
            end
        end
    end
    return transformed_table
end

function M.run_searches(opts, settings)
    local jobs = {}
    local job_count = 0
    local results = {}

    if #opts.args > 0 then
        local manual_search = {
            name = "Manual",
            command = utils.expand_home_path(opts.args)
        }
        table.insert(settings.search, manual_search)
    end

    local function on_event(job_id, data, event)
        local job_name = jobs[job_id] -- Retrieve the job's name for more informative output
        if event == 'stdout' and data then
            if not results[job_id] then results[job_id] = {} end
            for _, line in ipairs(data) do
                table.insert(results[job_id], line)
            end
        elseif event == 'stderr' and data then
            if data and #data > 0 then -- Check if there is actual data to process
                for _, line in ipairs(data) do
                    if line ~= "" then -- Ensure the line isn't empty
                        print("Error from job " .. job_name .. " : " .. vim.inspect(line))
                    end
                end
            end
        elseif event == 'exit' then
            job_count = job_count - 1
            --print(job_name .. " (" .. job_id .. ") completed.") -- Print which job has completed
            if job_count == 0 then
                -- All jobs have completed
                --print("All search jobs completed")
                -- Process results or print them
                for id, lines in pairs(results) do
                    print("Results from " .. jobs[id] .. ":") -- Use job_name for clarity
                    for _, line in ipairs(lines) do
                        print(line)
                    end
                end

                local gui = require 'venv-selector.gui'
                gui.show(M.convert_for_gui(results))
            end
        end
    end


    -- Start each job
    for _, search in ipairs(settings.search) do
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
    -- TODO: Make it possible to give a search on the command line and have results in the GUI.
    -- TODO: Need to stop the search if it takes too long to have a good user experience.
    M.run_searches(opts, settings)
end

return M
