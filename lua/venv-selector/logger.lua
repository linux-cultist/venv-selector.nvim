-- lua/venv-selector/logger.lua
--
-- In-editor logging for venv-selector.nvim.
--
-- Responsibilities:
-- - Provide log functions with levels (DEBUG/INFO/WARNING/ERROR).
-- - Append log lines to a dedicated scratch buffer (VenvSelectLog).
-- - Apply syntax highlighting in that buffer.
-- - Toggle displaying the log buffer in the current window.
-- - (Optional) Forward selected vim.lsp.log messages into this logger.
--
-- Design notes:
-- - Buffer writes are scheduled to avoid "E565: Not allowed to change text or change window".
-- - Logging is gated by both `M.enabled` and the current log level threshold.
-- - The log buffer is a scratch buffer (listed=false, scratch=true).

local log_buf = nil
local prev_buf = nil
local buffer_name = "VenvSelectLog"

local M = {}

-- ============================================================================
-- Levels + highlighting configuration
-- ============================================================================

---Numeric log levels (lower = more verbose).
---@type table<string, integer>
M.levels = {
    DEBUG = 1,
    INFO = 2,
    WARNING = 3,
    ERROR = 4,
    NONE = 5,
}

---Highlight groups to link to (theme-provided groups).
---@type table<string, string>
M.colors = {
    DEBUG = "Comment",
    INFO = "DiagnosticInfo",
    WARNING = "DiagnosticWarn",
    ERROR = "DiagnosticError",
    TIMESTAMP = "Special",
}

---Current minimum log level; messages below this are ignored.
---@type integer
M.current_level = M.levels.DEBUG

---Global logging enable switch for this logger buffer.
---@type boolean
M.enabled = false

-- ============================================================================
-- Level management
-- ============================================================================

---Set the active minimum log level.
---
---@param level string One of: "DEBUG"|"INFO"|"WARNING"|"ERROR"|"NONE"
function M.set_level(level)
    if M.levels[level] then
        M.current_level = M.levels[level]
    else
        error("Invalid log level: " .. level)
    end
end

---Get the active minimum log level name.
---
---@return string|nil level_name
function M.get_level()
    for k, v in pairs(M.levels) do
        if v == M.current_level then
            return k
        end
    end
    return nil
end

---Log each argument separately at the given level.
---This preserves existing call-sites that do `log.debug("a", tbl, "b")`.
---
---@param level string
---@param ... any
function M.iterate_args(level, ...)
    for i = 1, select("#", ...) do
        local msg = select(i, ...)
        M.log(level, msg, 1)
    end
end

---Convenience: DEBUG log for varargs.
---@param ... any
function M.debug(...)
    M.iterate_args("DEBUG", ...)
end

---Convenience: INFO log for varargs.
---@param ... any
function M.info(...)
    M.iterate_args("INFO", ...)
end

---Convenience: WARNING log for varargs.
---@param ... any
function M.warning(...)
    M.iterate_args("WARNING", ...)
end

---Convenience: ERROR log for varargs.
---@param ... any
function M.error(...)
    M.iterate_args("ERROR", ...)
end

-- ============================================================================
-- Formatting helpers
-- ============================================================================

---Return a UTC timestamp in a stable format.
---
---@return string utc_timestamp "YYYY-MM-DD HH:MM:SS"
function M.get_utc_date_time()
    local utc_time = os.date("!%Y-%m-%d %H:%M:%S", os.time())
    return utc_time
end

---Recursively log a table in an indented "key: value" form.
---This uses DEBUG level for all emitted lines.
---
---@param tbl table
---@param indent? integer
function M.log_table(tbl, indent)
    if M.enabled == false then
        return
    end
    indent = indent or 0

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

-- ============================================================================
-- Log buffer creation + highlighting
-- ============================================================================

---Configure buffer-local options and apply syntax highlighting rules.
---Safe to call repeatedly; no-op if log buffer is missing/invalid.
function M.setup_syntax_highlighting()
    if log_buf == nil or not vim.api.nvim_buf_is_valid(log_buf) then
        return
    end

    -- Buffer display settings.
    vim.bo[log_buf].filetype = "venv-selector-log"
    vim.bo[log_buf].modifiable = false
    vim.bo[log_buf].readonly = true

    -- Highlight group definitions (linked to theme highlight groups).
    local highlights = {
        { name = "VenvLogTimestamp", link = M.colors.TIMESTAMP },
        { name = "VenvLogDebug", link = M.colors.DEBUG },
        { name = "VenvLogInfo", link = M.colors.INFO },
        { name = "VenvLogWarning", link = M.colors.WARNING },
        { name = "VenvLogError", link = M.colors.ERROR },
    }

    for _, hl in ipairs(highlights) do
        vim.api.nvim_set_hl(0, hl.name, { link = hl.link })
    end

    -- Syntax patterns. These attach highlight groups to timestamp + [LEVEL] tags.
    vim.api.nvim_buf_call(log_buf, function()
        vim.cmd("syntax clear")
        vim.cmd([[syntax match VenvLogTimestamp /^\d\{4\}-\d\{2\}-\d\{2\} \d\{2\}:\d\{2\}:\d\{2\}/]])
        vim.cmd([[syntax match VenvLogDebug /\[DEBUG\]/]])
        vim.cmd([[syntax match VenvLogInfo /\[INFO\]/]])
        vim.cmd([[syntax match VenvLogWarning /\[WARNING\]/]])
        vim.cmd([[syntax match VenvLogError /\[ERROR\]/]])
    end)
end

-- ============================================================================
-- Core log writer
-- ============================================================================

---Append a formatted log entry to the log buffer.
---Uses vim.schedule to avoid text-change restrictions in callbacks/autocmd contexts.
---
---@param msg string
---@param level string
function M.log_line(msg, level)
    if M.enabled == false then
        return
    end

    vim.schedule(function()
        -- Ensure log buffer exists.
        if log_buf == nil or not vim.api.nvim_buf_is_valid(log_buf) then
            log_buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_name(log_buf, buffer_name)
            vim.api.nvim_buf_set_lines(log_buf, 0, -1, false, {})
            M.setup_syntax_highlighting()
        end

        -- Temporarily suppress warnings during buffer modification.
        local old_shortmess = vim.o.shortmess
        vim.o.shortmess = vim.o.shortmess .. "W"

        -- Make buffer writable for the append.
        vim.bo[log_buf].readonly = false
        vim.bo[log_buf].modifiable = true

        local line_count = vim.api.nvim_buf_line_count(log_buf)
        local utc_time_stamp = M.get_utc_date_time()
        local log_entry = string.format("%s [%s]: %s", utc_time_stamp, level, msg)

        -- If the buffer is empty (single empty line), replace it; else append.
        if line_count == 1 and vim.api.nvim_buf_get_lines(log_buf, 0, 1, false)[1] == "" then
            vim.api.nvim_buf_set_lines(log_buf, 0, 1, false, { log_entry })
        else
            vim.api.nvim_buf_set_lines(log_buf, line_count, line_count, false, { log_entry })
        end

        -- Restore buffer state and warning settings.
        vim.bo[log_buf].modifiable = false
        vim.bo[log_buf].readonly = true
        vim.o.shortmess = old_shortmess
    end)
end

---Log a message (string or table) at the given level.
---Respects current minimum log level threshold.
---
---@param level string
---@param msg any
---@param indent? integer
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

-- ============================================================================
-- UI: toggle log buffer
-- ============================================================================

---Toggle showing the log buffer in the current window.
---If the log buffer is currently displayed, switches back to the previous buffer.
---
---@return integer|nil status Historically returns 1 if disabled; otherwise nil
function M.toggle()
    if M.enabled == false then
        return 1
    end

    local current_buf = vim.api.nvim_win_get_buf(0)

    if current_buf == log_buf then
        -- Leaving the log buffer: restore previous buffer if possible.
        if prev_buf and vim.api.nvim_buf_is_valid(prev_buf) then
            vim.api.nvim_win_set_buf(0, prev_buf)
        else
            vim.api.nvim_command("enew")
        end
        prev_buf = nil
    else
        -- Entering the log buffer: remember current buffer, then show log buffer.
        prev_buf = current_buf

        if log_buf == nil or not vim.api.nvim_buf_is_valid(log_buf) then
            log_buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_name(log_buf, buffer_name)
            M.setup_syntax_highlighting()
        end

        vim.api.nvim_win_set_buf(0, log_buf)

        -- Ensure syntax highlighting exists on every toggle (safe to re-run).
        M.setup_syntax_highlighting()
    end
end

---Find the window id currently displaying the log buffer (if any).
---
---@return integer|nil win Window handle, or nil if not visible
function M.find_log_window()
    local windows = vim.api.nvim_list_wins()
    for _, win in ipairs(windows) do
        if vim.api.nvim_win_get_buf(win) == log_buf then
            return win
        end
    end
    return nil
end

-- ============================================================================
-- LSP log forwarding
-- ============================================================================

---Names of python LSP clients that should be matched for log forwarding.
---If a vim.lsp.log message contains any of these names, it is forwarded to M.debug.
---
---@type table<string, true>
M.python_lsp_clients = {}

---Original vim.lsp.log functions (captured once).
---@type table<string, function>
local original_lsp_log = {}

---@type boolean
local log_forwarding_enabled = false

---Enable forwarding of selected vim.lsp.log messages into this logger.
---This wraps vim.lsp.log.error/warn/info (and preserves the originals).
function M.setup_lsp_message_forwarding()
    log_forwarding_enabled = true

    -- Store original functions if not already stored.
    if not original_lsp_log.error then
        original_lsp_log.error = vim.lsp.log.error
        original_lsp_log.warn = vim.lsp.log.warn
        original_lsp_log.info = vim.lsp.log.info
        original_lsp_log.debug = vim.lsp.log.debug
        original_lsp_log.trace = vim.lsp.log.trace
    end

    ---Convert arbitrary log arguments to a single-line string.
    ---Tables are converted with vim.inspect.
    ---
    ---@param ... any
    ---@return string message
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

        -- Remove newlines and compress whitespace.
        local message = table.concat(parts, " ")
        return message
            :gsub("\n", " ")
            :gsub("\r", "")
            :gsub("%s+", " ")
            :match("^%s*(.-)%s*$")
    end

    ---Forward helper used by the wrappers below.
    ---
    ---@param message string
    local function maybe_forward(message)
        for client_name, _ in pairs(M.python_lsp_clients) do
            if message:find(client_name, 1, true) then
                M.debug("[" .. client_name .. " LSP] " .. message)
                break
            end
        end
    end

    -- Override log functions to capture Python LSP messages.
    vim.lsp.log.error = function(...)
        local message = args_to_string(...)
        maybe_forward(message)
        return original_lsp_log.error(...)
    end

    vim.lsp.log.warn = function(...)
        local message = args_to_string(...)
        maybe_forward(message)
        return original_lsp_log.warn(...)
    end

    vim.lsp.log.info = function(...)
        local message = args_to_string(...)
        maybe_forward(message)
        return original_lsp_log.info(...)
    end
end

---Disable LSP log forwarding and restore original vim.lsp.log functions.
function M.disable_lsp_log_forwarding()
    if not log_forwarding_enabled then
        return
    end

    vim.lsp.log.error = original_lsp_log.error
    vim.lsp.log.warn = original_lsp_log.warn
    vim.lsp.log.info = original_lsp_log.info
    vim.lsp.log.debug = original_lsp_log.debug
    vim.lsp.log.trace = original_lsp_log.trace

    log_forwarding_enabled = false
end

---Register a python LSP client name for forwarding.
---Callers should call this for clients like "pyright", "pylsp", "ruff_lsp", etc.
---
---@param client_name string
function M.track_python_lsp(client_name)
    M.python_lsp_clients[client_name] = true
end

-- Enable forwarding by default (preserved behavior).
M.setup_lsp_message_forwarding()

return M
