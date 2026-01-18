local log_buf = nil
local prev_buf = nil
local buffer_name = "VenvSelectLog"
local M = {}

M.levels = {
    DEBUG = 1,
    INFO = 2,
    WARNING = 3,
    ERROR = 4,
    NONE = 5,
}

-- Color scheme for different log levels using theme colors
M.colors = {
    DEBUG = "Comment",          -- Use comment color (usually gray)
    INFO = "DiagnosticInfo",    -- Use diagnostic info color (usually blue)
    WARNING = "DiagnosticWarn", -- Use diagnostic warning color (usually orange)
    ERROR = "DiagnosticError",  -- Use diagnostic error color (usually red)
    TIMESTAMP = "Special",      -- Use special color (usually purple/magenta)
}

M.current_level = M.levels.DEBUG
M.enabled = false

function M.set_level(level)
    if M.levels[level] then
        M.current_level = M.levels[level]
    else
        error("Invalid log level: " .. level)
    end
end

function M.iterate_args(level, ...)
    for i = 1, select("#", ...) do
        local msg = select(i, ...)
        M.log(level, msg, 1)
    end
end

function M.get_level()
    for k, v in pairs(M.levels) do
        if v == M.current_level then
            return k
        end
    end
    return nil
end

function M.debug(...)
    M.iterate_args("DEBUG", ...)
end

function M.info(...)
    M.iterate_args("INFO", ...)
end

function M.warning(...)
    M.iterate_args("WARNING", ...)
end

function M.error(...)
    M.iterate_args("ERROR", ...)
end

function M.get_utc_date_time()
    local utc_time = os.date("!%Y-%m-%d %H:%M:%S", os.time())
    return utc_time
end

function M.log_table(tbl, indent)
    if M.enabled == false then
        return
    end
    if not indent then
        indent = 0
    end

    for k, v in pairs(tbl) do
        local formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            M.log("DEBUG", formatting)
            M.log_table(v, indent + 1)
        else
            M.log("DEBUG", formatting .. tostring(v))
        end
    end
end

function M.setup_syntax_highlighting()
    if log_buf == nil or not vim.api.nvim_buf_is_valid(log_buf) then
        return
    end

    -- Set buffer options for better display
    vim.bo[log_buf].filetype = 'venv-selector-log'
    vim.bo[log_buf].modifiable = false
    vim.bo[log_buf].readonly = true

    -- Create highlight groups for different log components using theme colors
    local highlights = {
        { name = "VenvLogTimestamp", link = M.colors.TIMESTAMP },
        { name = "VenvLogDebug",     link = M.colors.DEBUG },
        { name = "VenvLogInfo",      link = M.colors.INFO },
        { name = "VenvLogWarning",   link = M.colors.WARNING },
        { name = "VenvLogError",     link = M.colors.ERROR },
    }

    for _, hl in ipairs(highlights) do
        vim.api.nvim_set_hl(0, hl.name, { link = hl.link })
    end

    -- Define syntax patterns
    vim.api.nvim_buf_call(log_buf, function()
        vim.cmd('syntax clear')
        vim.cmd('syntax match VenvLogTimestamp /^\\d\\{4\\}-\\d\\{2\\}-\\d\\{2\\} \\d\\{2\\}:\\d\\{2\\}:\\d\\{2\\}/')
        vim.cmd('syntax match VenvLogDebug /\\[DEBUG\\]/')
        vim.cmd('syntax match VenvLogInfo /\\[INFO\\]/')
        vim.cmd('syntax match VenvLogWarning /\\[WARNING\\]/')
        vim.cmd('syntax match VenvLogError /\\[ERROR\\]/')
    end)
end

function M.log_line(msg, level)
    if M.enabled == false then
        return
    end

    -- Wrap buffer operations in vim.schedule to avoid E565
    vim.schedule(function()
        if log_buf == nil or not vim.api.nvim_buf_is_valid(log_buf) then
            log_buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_name(log_buf, buffer_name)
            vim.api.nvim_buf_set_lines(log_buf, 0, -1, false, {})
            M.setup_syntax_highlighting()
        end

        -- Temporarily suppress warnings during buffer modification
        local old_shortmess = vim.o.shortmess
        vim.o.shortmess = vim.o.shortmess .. "W"

        -- Make buffer modifiable for updates
        vim.bo[log_buf].readonly = false
        vim.bo[log_buf].modifiable = true

        local line_count = vim.api.nvim_buf_line_count(log_buf)
        local utc_time_stamp = M.get_utc_date_time()
        local log_entry = string.format("%s [%s]: %s", utc_time_stamp, level, msg)

        if line_count == 1 and vim.api.nvim_buf_get_lines(log_buf, 0, 1, false)[1] == "" then
            vim.api.nvim_buf_set_lines(log_buf, 0, 1, false, { log_entry })
        else
            vim.api.nvim_buf_set_lines(log_buf, line_count, line_count, false, { log_entry })
        end

        -- Restore buffer state and warning settings
        vim.bo[log_buf].modifiable = false
        vim.bo[log_buf].readonly = true
        vim.o.shortmess = old_shortmess
    end)
end

function M.log(level, msg, indent)
    if M.levels[level] == nil or M.levels[level] < M.current_level then
        return
    end

    if type(msg) == "table" then
        M.log_table(msg, indent)
    else
        M.log_line(msg, level)
    end
end

function M.toggle()
    if M.enabled == false then
        return 1
    end

    local current_buf = vim.api.nvim_win_get_buf(0)

    if current_buf == log_buf then
        if prev_buf and vim.api.nvim_buf_is_valid(prev_buf) then
            vim.api.nvim_win_set_buf(0, prev_buf)
        else
            vim.api.nvim_command("enew")
        end
        prev_buf = nil
    else
        prev_buf = current_buf
        if log_buf == nil or not vim.api.nvim_buf_is_valid(log_buf) then
            log_buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_name(log_buf, buffer_name)
            M.setup_syntax_highlighting()
        end
        vim.api.nvim_win_set_buf(0, log_buf)

        -- Ensure syntax highlighting is applied when toggling to log buffer
        M.setup_syntax_highlighting()
    end
end

function M.find_log_window()
    local windows = vim.api.nvim_list_wins()
    for _, win in ipairs(windows) do
        if vim.api.nvim_win_get_buf(win) == log_buf then
            return win
        end
    end
    return nil
end

-- LSP log forwarding functionality
M.python_lsp_clients = {}

-- Store original vim.lsp.log functions
local original_lsp_log = {}
local log_forwarding_enabled = false

-- Setup comprehensive LSP message forwarding
function M.setup_lsp_message_forwarding()
    log_forwarding_enabled = true

    -- Store original functions if not already stored
    if not original_lsp_log.error then
        original_lsp_log.error = vim.lsp.log.error
        original_lsp_log.warn = vim.lsp.log.warn
        original_lsp_log.info = vim.lsp.log.info
        original_lsp_log.debug = vim.lsp.log.debug
        original_lsp_log.trace = vim.lsp.log.trace
    end

    -- Helper function to safely convert arguments to string
    local function args_to_string(...)
        local args = { ... }
        local parts = {}
        for i, arg in ipairs(args) do
            if type(arg) == "table" then
                parts[i] = vim.inspect(arg)
            else
                parts[i] = tostring(arg)
            end
        end
        -- Remove newlines and sanitize for logging
        local message = table.concat(parts, " ")
        return message:gsub("\n", " "):gsub("\r", ""):gsub("%s+", " "):match("^%s*(.-)%s*$")
    end

    -- Override log functions to capture Python LSP messages
    vim.lsp.log.error = function(...)
        local message = args_to_string(...)

        -- Check if message contains Python LSP client names
        for client_name, _ in pairs(M.python_lsp_clients) do
            if message:find(client_name) then
                M.debug("[" .. client_name .. " LSP] " .. message)
                break
            end
        end

        return original_lsp_log.error(...)
    end

    vim.lsp.log.warn = function(...)
        local message = args_to_string(...)

        for client_name, _ in pairs(M.python_lsp_clients) do
            if message:find(client_name) then
                M.debug("[" .. client_name .. " LSP] " .. message)
                break
            end
        end

        return original_lsp_log.warn(...)
    end

    vim.lsp.log.info = function(...)
        local message = args_to_string(...)

        for client_name, _ in pairs(M.python_lsp_clients) do
            if message:find(client_name) then
                M.debug("[" .. client_name .. " LSP] " .. message)
                break
            end
        end

        return original_lsp_log.info(...)
    end
end

-- Restore original LSP log functions
function M.disable_lsp_log_forwarding()
    if not log_forwarding_enabled then return end

    vim.lsp.log.error = original_lsp_log.error
    vim.lsp.log.warn = original_lsp_log.warn
    vim.lsp.log.info = original_lsp_log.info
    vim.lsp.log.debug = original_lsp_log.debug
    vim.lsp.log.trace = original_lsp_log.trace

    log_forwarding_enabled = false
end

-- Track a Python LSP client for log forwarding
function M.track_python_lsp(client_name)
    M.python_lsp_clients[client_name] = true
end

-- Initialize LSP log forwarding
M.setup_lsp_message_forwarding()

return M
