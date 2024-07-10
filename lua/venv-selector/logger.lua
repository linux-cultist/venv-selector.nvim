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

function M.log_line(msg, level)
    if M.enabled == false then
        return
    end
    if log_buf == nil or not vim.api.nvim_buf_is_valid(log_buf) then
        log_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(log_buf, buffer_name)
        vim.api.nvim_buf_set_lines(log_buf, 0, -1, false, {})
    end

    local line_count = vim.api.nvim_buf_line_count(log_buf)
    local utc_time_stamp = M.get_utc_date_time()
    local log_entry = string.format("%s [%s]: %s", utc_time_stamp, level, msg)

    -- Replace the first line if it's empty, or append the new log entry
    if line_count == 1 and vim.api.nvim_buf_get_lines(log_buf, 0, 1, false)[1] == "" then
        vim.api.nvim_buf_set_lines(log_buf, 0, 1, false, { log_entry })
    else
        vim.api.nvim_buf_set_lines(log_buf, line_count, line_count, false, { log_entry })
    end
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
        end
        vim.api.nvim_win_set_buf(0, log_buf)
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

return M
