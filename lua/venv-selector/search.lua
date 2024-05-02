local utils = require 'venv-selector.utils'


local M = {}

function M.flatten_table(nested_tbl)
    local flat_table = {}
    for _, sublist in pairs(nested_tbl) do
        for _, item in ipairs(sublist) do
            if item ~= "" then  -- Skip empty strings
                table.insert(flat_table, item)
            end
        end
    end
    return flat_table
end



function M.run_searches(settings)
    local jobs = {}
    local job_count = 0
    local results = {}

    local function on_event(job_id, data, event)
        local job_name = jobs[job_id] -- Retrieve the job's name for more informative output
        if event == 'stdout' and data then
            if not results[job_id] then results[job_id] = {} end
            for _, line in ipairs(data) do
                table.insert(results[job_id], line)
            end
        elseif event == 'stderr' and data then
            if data and #data > 0 then         -- Check if there is actual data to process
                for _, line in ipairs(data) do
                    if line ~= "" then         -- Ensure the line isn't empty
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
                gui.show(M.flatten_table(results))
            end
        end
    end


    -- Start each job
    for _, search in ipairs(settings.search) do
        local job_id = vim.fn.jobstart(utils.expand_path(search.command), {
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
    M.run_searches(settings)
end

return M
