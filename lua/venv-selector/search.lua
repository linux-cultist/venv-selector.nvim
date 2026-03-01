-- lua/venv-selector/search.lua
--
-- Search engine for venv-selector.nvim.
--
-- Responsibilities:
-- - Execute one or more configured search commands (usually via `fd`) to find python executables.
-- - Stream results into a picker UI (telescope/fzf/snacks/mini/native) or callback table.
-- - Support an "interactive search" mode that replaces configured searches.
-- - Track running jobs and allow cancellation via `stop_search()`.
--
-- Design notes:
-- - Searches run concurrently as background jobs (vim.fn.jobstart).
-- - Completion is detected when the last tracked job exits.
-- - Results are emitted line-by-line from stdout callbacks.
--
-- Conventions:
-- - SearchResult.path is a path to the python executable.
-- - SearchResult.name is a display name (potentially transformed by callbacks).
-- - SearchResult.type and SearchResult.source identify the search origin.
--
-- Buffer scoping note:
-- - $WORKSPACE_PATH expansion is now scoped to a "context buffer" when possible, so searches
--   only use workspace folders relevant to the buffer the user invoked the picker from.
-- - This avoids searching all workspaces across the whole session, and avoids picker-buffer
--   issues (where current buffer is the picker prompt/results buffer).

local workspace = require("venv-selector.workspace")
local path = require("venv-selector.path")
local utils = require("venv-selector.utils")
local log = require("venv-selector.logger")

-- Load shared annotations/types (kept as a module so other files can @class reference it).
require("venv-selector.types")

local M = {}

-- ============================================================================
-- Module state
-- ============================================================================

---Active job registry keyed by job id.
---@type table<integer, venv-selector.ActiveJobState>
M.active_jobs = M.active_jobs or {}

---True while a search run is in progress.
---@type boolean
M.search_in_progress = M.search_in_progress or false

---Count tracked jobs currently in M.active_jobs.
---@return integer n
local function active_job_count()
    local n = 0
    for _ in pairs(M.active_jobs) do
        n = n + 1
    end
    return n
end

---Return true if a job is still running.
---jobwait returns -1 if still running after the given timeout (0ms here).
---@param jid integer
---@return boolean running
local function job_is_running(jid)
    local r = vim.fn.jobwait({ jid }, 0)[1]
    return r == -1
end

-- ============================================================================
-- Public API: cancellation
-- ============================================================================

---Stop all currently running search jobs and clear state.
---Safe to call multiple times.
function M.stop_search()
    if not M.search_in_progress then
        return
    end
    M.search_in_progress = false

    for jid, _cfg in pairs(M.active_jobs or {}) do
        pcall(vim.fn.jobstop, jid)
    end

    M.active_jobs = {}
    log.debug("All searches stopped.")
end

-- ============================================================================
-- Internal helpers
-- ============================================================================

---@param bufnr integer
---@return boolean
local function is_normal_python_buf(bufnr)
    return type(bufnr) == "number"
        and bufnr > 0
        and vim.api.nvim_buf_is_valid(bufnr)
        and vim.bo[bufnr].buftype == ""
        and vim.bo[bufnr].filetype == "python"
end

---Pick a "context buffer" for scoping workspace folder discovery.
---This avoids picker buffers (prompt/results) accidentally becoming the scope.
---
---Priority:
--- 1) opts.bufnr if provided and valid
--- 2) current buffer if it's a normal python buffer
--- 3) alternate buffer (#) if it's a normal python buffer
--- 4) fallback to current buffer
---@param opts venv-selector.SearchOpts|nil
---@return integer bufnr
local function resolve_context_bufnr(opts)
    if opts and type(opts.bufnr) == "number" and vim.api.nvim_buf_is_valid(opts.bufnr) then
        return opts.bufnr
    end

    local cur = vim.api.nvim_get_current_buf()
    if is_normal_python_buf(cur) then
        return cur
    end

    local alt = vim.fn.bufnr("#")
    if type(alt) == "number" and alt > 0 and is_normal_python_buf(alt) then
        return alt
    end

    return cur
end

---Get the current file path, falling back to alternate buffer if current is empty.
---Useful when the command is invoked from a non-file buffer.
---@return string current_file Absolute file path or "" if none
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

---Expand "~" and "$VARS" in a shell command string.
---Rules:
--- - "~" expanded only at start
--- - "$VAR" expanded from vim.env (missing vars become "")
---@param s string
---@return string expanded
local function expand_env(s)
    s = s:gsub("^~", vim.fn.expand("~"))
    s = s:gsub("%$([%w_]+)", function(k)
        return vim.env[k] or ""
    end)
    return s
end

---Create a job event handler that:
--- - Emits results on stdout
--- - Collects stderr
--- - Detects completion when the last tracked job exits
---@param picker venv-selector.Picker|venv-selector.SearchCallbacks|nil
---@param options table User options (contains callbacks/icons)
---@return fun(job_id: integer, data: any, event: string)
local function create_job_event_handler(picker, options)
    return function(job_id, data, event)
        local search_config = M.active_jobs[job_id]
        if not search_config then
            return
        end

        if event == "stdout" and data then
            local callback = search_config.on_telescope_result_callback
                or options.on_telescope_result_callback
                or search_config.on_fd_result_callback
                or options.on_fd_result_callback

            for _, line in ipairs(data) do
                if line ~= "" then
                    ---@type venv-selector.SearchResult
                    local result = {
                        path = line,
                        name = callback and callback(line, search_config.name) or line,
                        icon = options.icon or "",
                        type = search_config.type or "venv",
                        source = search_config.name,
                    }

                    log.trace("Found " .. result.type .. " from " .. result.source .. ": " .. result.name)

                    if picker then
                        local p = picker
                        if type(p.insert_result) == "function" then
                            ---@cast p venv-selector.Picker
                            p:insert_result(result)
                        elseif type(p.on_result) == "function" then
                            ---@cast p venv-selector.SearchCallbacks
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
                log.trace(error_msg)
            else
                log.trace("Search job '" .. search_config.name .. "' completed successfully")
            end

            local n = active_job_count()
            local last = (n == 1) and (M.active_jobs[job_id] ~= nil)

            if last then
                log.info("Searching finished.")

                if picker then
                    local p = picker
                    if type(p.search_done) == "function" then
                        ---@cast p venv-selector.Picker
                        vim.schedule(function()
                            p:search_done()
                        end)
                    elseif type(p.on_complete) == "function" then
                        ---@cast p venv-selector.SearchCallbacks
                        vim.schedule(function()
                            p.on_complete()
                        end)
                    end
                end

                M.search_in_progress = false
            end
        end
    end
end

-- ============================================================================
-- Job execution
-- ============================================================================

---Start a single search job.
---The search_config must already contain `execute_command`.
---@param search_name string Name of the search (used as SearchResult.source)
---@param search_config venv-selector.SearchConfig
---@param job_event_handler fun(job_id: integer, data: any, event: string)
---@param search_timeout integer Timeout in seconds
local function start_search_job(search_name, search_config, job_event_handler, search_timeout)
    if not search_config.execute_command then
        log.error("No execute_command for search '" .. search_name .. "'")
        return
    end

    local job = search_config.execute_command
    ---@cast job string
    local expanded_job = expand_env(job) -- expands $VAR and ~

    local options = require("venv-selector.config").get_user_options()
    local shell = options.shell.shell
    local shell_cmdflags = options.shell.shellcmdflag
    if type(shell_cmdflags) == "string" then
        shell_cmdflags = utils.split_string(shell_cmdflags)
    end

    -- On PowerShell (pwsh / powershell), anything after the -Command / /c flag
    -- in shellcmdflag is a Neovim terminal encoding preamble (e.g. setting
    -- $PSDefaultParameterValues or [Console]::OutputEncoding). That preamble is
    -- only needed for Neovim's own interactive terminal and must not be forwarded
    -- to fd search jobs for two reasons:
    --
    --   1. split_string strips quotes, corrupting key literals such as
    --      ['Out-File:Encoding'] -> [Out-File:Encoding], which is invalid
    --      PowerShell syntax and causes a ParserError on every search job.
    --
    --   2. fd produces plain ASCII paths and requires no encoding setup.
    --
    -- Truncate shell_cmdflags at -Command (inclusive) so the fd command is the
    -- only argument that follows.
    local shell_basename = shell:match("[^\\/]+$") or shell
    local is_powershell = shell_basename:lower() == "pwsh" or shell_basename:lower() == "powershell"

    if is_powershell then
        local command_flag_idx = nil
        for i, flag in ipairs(shell_cmdflags) do
            if flag:lower() == "-command" or flag:lower() == "/c" then
                command_flag_idx = i
                break
            end
        end
        if command_flag_idx then
            while #shell_cmdflags > command_flag_idx do
                table.remove(shell_cmdflags)
            end
        end
    end

    local cmd = utils.extend({ options.shell.shell }, shell_cmdflags, { expanded_job })

    log.debug(
        "Executing search '"
            .. search_name
            .. "' (using "
            .. shell
            .. " "
            .. table.concat(shell_cmdflags, " ")
            .. "): '"
            .. expanded_job
            .. "'"
    )

    local function on_exit_wrapper(jid, data, event)
        job_event_handler(jid, data, event)
        if M.active_jobs and M.active_jobs[jid] then
            M.active_jobs[jid] = nil
        end
    end

    local job_id = vim.fn.jobstart(cmd, {
        stdout_buffered = false,
        stderr_buffered = false,
        on_stdout = job_event_handler,
        on_stderr = job_event_handler,
        on_exit = on_exit_wrapper,
    })

    if job_id <= 0 then
        local err = job_id == 0 and "invalid arguments" or "command not executable"
        log.error("Failed to start job '" .. search_name .. "': " .. err .. ". Command: " .. vim.inspect(job))
        return
    end

    ---@type venv-selector.ActiveJobState
    local job_state = vim.tbl_extend("force", {}, search_config, {
        name = search_name,
    })

    M.active_jobs[job_id] = job_state

    local timer = vim.uv.new_timer()
    if timer then
        timer:start(search_timeout * 1000, 0, vim.schedule_wrap(function()
            if vim.fn.jobwait({ job_id }, 0)[1] == -1 then
                vim.fn.jobstop(job_id)
                local msg = "Search '" .. search_name .. "' took more than " .. search_timeout
                    .. " seconds and was stopped. Avoid using VenvSelect in $HOME directory."
                log.warning(msg)
                vim.notify(msg, vim.log.levels.ERROR, { title = "VenvSelect" })
            end
            timer:stop()
            timer:close()
        end))
    end
end

---Process a search config and start one or more jobs based on its substitution patterns.
---@param search_name string
---@param search_config venv-selector.SearchConfig
---@param job_event_handler fun(job_id: integer, data: any, event: string)
---@param options table User options
---@param context_bufnr integer Buffer used to scope $WORKSPACE_PATH discovery
local function process_search(search_name, search_config, job_event_handler, options, context_bufnr)
    local cmd = search_config.command:gsub("$FD", options.fd_binary_name)

    if cmd:find("$WORKSPACE_PATH") then
        -- Scope to context buffer to avoid searching all workspaces in the whole session.
        for _, workspace_path in pairs(workspace.list_folders(context_bufnr)) do
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

-- ============================================================================
-- Main entrypoint
-- ============================================================================

---Run all configured searches and stream results into a picker/callback.
---
---opts.bufnr (optional):
---If provided, scopes $WORKSPACE_PATH discovery to that buffer's attached LSP clients.
---If not provided, a best-effort context buffer is chosen (avoids picker buffers).
---
---@param picker venv-selector.Picker|venv-selector.SearchCallbacks|nil
---@param opts venv-selector.SearchOpts|nil
function M.run_search(picker, opts)
    if M.search_in_progress then
        log.info("Stopping previous search before starting new one.")
        M.stop_search()
    end

    M.search_in_progress = true

    local user_settings = require("venv-selector.config").user_settings
    local options = user_settings.options

    local context_bufnr = resolve_context_bufnr(opts)

    local search_settings = user_settings
    if opts and type(opts.args) == "string" and #opts.args > 0 then
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

    if not options.enable_default_searches then
        local default_searches = require("venv-selector.config").get_default_searches()
        for search_name, _search_config in pairs(search_settings.search) do
            if default_searches[search_name] then
                log.debug("Disabling default search: '" .. search_name .. "'")
                search_settings.search[search_name] = nil
            end
        end
    end

    M.active_jobs = {}
    local job_event_handler = create_job_event_handler(picker, options)

    for search_name, search_command in pairs(search_settings.search) do
        if search_command ~= true and search_command ~= false then
            ---@type venv-selector.SearchConfig
            local search_config = vim.tbl_extend("force", {}, search_command, {
                name = search_name,
            })
            process_search(search_name, search_config, job_event_handler, options, context_bufnr)
        end
    end
end

return M
