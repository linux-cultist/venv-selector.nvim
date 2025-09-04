local config = require("venv-selector.config")
local events = require("venv-selector.events")
local log = require("venv-selector.logger")

local M = {}

-- Cache for search results to avoid re-searching on every open
local search_cache = {
    results = {},
    has_results = false
}

-- Function to clear search cache
function M.clear_cache()
    search_cache.results = {}
    search_cache.has_results = false
end

local function resolve_picker()
    local picker = require("venv-selector.config").user_settings.options.picker

    -- Picker configurations in priority order
    local pickers = {
        { name = "telescope", module = "telescope" },
        { name = "fzf-lua",   module = "fzf-lua" },
        { name = "snacks",    module = "snacks" },
        { name = "mini-pick", module = "mini.pick" },
        { name = "native",    module = nil }, -- native doesn't require a module
    }

    -- Check installation status for all pickers
    local picker_status = {}
    for _, p in ipairs(pickers) do
        if p.module then
            picker_status[p.name] = pcall(require, p.module)
        else
            picker_status[p.name] = true -- native is always available
        end
    end

    if picker == "auto" then
        -- Find first installed picker in priority order
        for _, p in ipairs(pickers) do
            if picker_status[p.name] then
                return p.name
            end
        end
        return "native" -- fallback
    elseif picker == "native" then
        return "native"
    else
        -- Validate specific picker choice
        local picker_found = false
        for _, p in ipairs(pickers) do
            if p.name == picker then
                picker_found = true
                if not picker_status[picker] then
                    local message = "VenvSelect picker is set to " ..
                        picker .. ", but " .. picker .. " is not installed."
                    vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
                    log.error(message)
                    return
                end
                return picker
            end
        end

        -- Invalid picker name
        if not picker_found then
            local message = 'VenvSelect: invalid picker "' .. picker .. '" selected.'
            vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
            log.error(message)
            return
        end
    end
end

function M.open(opts)
    local options = require("venv-selector.config").user_settings.options
    if options.fd_binary_name == nil then
        local message =
        "Cannot find any fd binary on your system. If its installed under a different name, you can set options.fd_binary_name to its name."
        log.error(message)
        vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
        return
    end

    local selected_picker = resolve_picker()
    if selected_picker ~= nil then
        if selected_picker == "telescope" then
            -- Use streaming for telescope
            local picker = require("venv-selector.gui." .. selected_picker).new_streaming(opts)
            
            -- Open picker first
            picker:open_picker(opts)
            
            -- Check if we have cached results
            if search_cache.has_results and #search_cache.results > 0 then
                -- Use cached results
                for _, result in ipairs(search_cache.results) do
                    picker:insert_result(result)
                end
                picker:search_done()
            else
                -- Setup events to cache results during streaming
                local picker_id = tostring(picker)
                local result_event = "search_result_found_" .. picker_id
                local complete_event = "search_complete_" .. picker_id
                
                events.on(result_event, function(args)
                    -- Cache the result
                    table.insert(search_cache.results, args.data.result)
                end, { once = false })
                
                events.on(complete_event, function(args)
                    search_cache.has_results = true
                end, { once = true })
                
                -- Start streaming search
                picker:setup_streaming_events(opts)
            end
        else
            -- Use regular approach for other pickers
            local picker = require("venv-selector.gui." .. selected_picker).new(opts)
            require("venv-selector.search").run_search(picker, opts)
        end
    end
end

-- Expose cache clearing function
M.clear_cache = M.clear_cache

return M
