local workspace = require("venv-selector.workspace")
local path = require("venv-selector.path")
local utils = require("venv-selector.utils")
local log = require("venv-selector.logger")
local config = require("venv-selector.config")
local gui = require("venv-selector.gui")

local M = {}

local function is_workspace_search(str)
    return string.find(str, "$WORKSPACE_PATH") ~= nil
end

local function is_cwd_search(str)
    return string.find(str, "$CWD") ~= nil
end

local function is_filepath_search(str)
    return string.find(str, "$FILE_DIR") ~= nil
end

local function disable_default_searches(search_settings)
    local default_searches = config.default_settings.search
    for search_name, _ in pairs(search_settings.search) do
        if default_searches[search_name] ~= nil then
            log.debug("Disabling default search for '" .. search_name .. '"')
            search_settings.search[search_name] = nil
        end
    end
end

local function set_interactive_search(opts)
    if opts ~= nil and opts.args ~= nil and #opts.args > 0 then
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

M.initial_opts = nil

function M.get_search_commands(opts)
    local user_settings = config.user_settings
    local options = user_settings.options
    local search_settings = set_interactive_search(opts) or user_settings

    if options.enable_default_searches == false then
        disable_default_searches(search_settings)
    end

    local fzf_search = {}
    local cwd = vim.fn.getcwd()
    local current_dir = path.get_current_file_directory()

    for job_name, search in pairs(search_settings.search) do
        if search ~= false then
            search.execute_command = search.command:gsub("$FD", options.fd_binary_name)
            if is_workspace_search(search.command) then
                local workspace_folders = workspace.list_folders()
                for _, workspace_path in pairs(workspace_folders) do
                    local cmd = search.execute_command:gsub("$WORKSPACE_PATH", workspace_path)
                    table.insert(fzf_search, cmd)
                end
            elseif is_cwd_search(search.command) then
                local cmd = search.execute_command:gsub("$CWD", cwd)
                table.insert(fzf_search, cmd)
            elseif is_filepath_search(search.command) then
                if current_dir ~= nil then
                    local cmd = search.execute_command:gsub("$FILE_DIR", current_dir)
                    table.insert(fzf_search, cmd)
                end
            else
                table.insert(fzf_search, search.execute_command)
            end
        end
    end

    return fzf_search
end

function M.run_search(opts)
    if M.search_in_progress == true then
        log.info("Not starting new search because previous search is still running.")
        return
    end

    -- Use the initial_opts if they exist, otherwise use the provided opts
    opts = opts or M.initial_opts or {}

    -- Store the initial opts if they haven't been stored yet
    if not M.initial_opts then
        M.initial_opts = opts
    end

    -- Clear previous results
    gui.results = {}

    local search_commands = M.get_search_commands(opts)
    local combined_command = table.concat(search_commands, "; ")

    M.search_in_progress = true
    log.debug("Starting combined search: '" .. combined_command .. "'")

    local handle = io.popen(combined_command)
    if handle then
        for line in handle:lines() do
            local rv = {
                path = line,
                name = line,
                icon = "",
                type = "venv",
                source = "combined_search",
            }

            gui:insert_result(rv)
        end
        handle:close()
    else
        log.error("Failed to execute search command")
    end

    log.info("Searching finished.")
    gui:remove_dups()
    gui:sort_results()
    gui:update_results()
    M.search_in_progress = false

    return combined_command
end

function M.New(opts)
    local options = config.user_settings.options
    if options.fd_binary_name == nil then
        local message =
            "Cannot find any fd binary on your system. If it's installed under a different name, you can set options.fd_binary_name to its name."
        log.error(message)
        vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
    elseif utils.check_dependencies_installed() == false then
        local message = "Not all required modules are installed."
        log.error(message)
        vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
    else
        M.run_search(opts)
    end
end

return M
