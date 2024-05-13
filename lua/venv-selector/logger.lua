local log_buf = nil
local prev_buf = nil
local buffer_name = "VenvSelectLog"
local M = {}


M.levels = {
    DEBUG = 1,
    INFO = 2,
    WARNING = 3,
    ERROR = 4,
    NONE = 5 -- To effectively disable logging
}

M.current_level = M.levels.DEBUG

function M.set_level(level)
    if M.levels[level] then
        M.current_level = M.levels[level]
    else
        error("Invalid log level: " .. level)
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

-- Function to add custom syntax highlighting to the log buffer
function M.add_syntax_highlighting()
    -- Define a syntax group
    vim.cmd("syntax match LogError '\\v<error>'")
    vim.cmd("syntax match LogWarning '\\v<warning>'")
    vim.cmd("syntax match LogInfo '\\v<info>'")

    -- Link syntax group to a highlight group
    vim.cmd("highlight link LogError ErrorMsg")
    vim.cmd("highlight link LogWarning WarningMsg")
    vim.cmd("highlight link LogInfo MoreMsg")
    vim.cmd("highlight link LogDebug Todo")
end

function M.highlight_words(buf_id, line_number, word, color_group)
    -- Ensure the line number is within the valid range
    if line_number < 1 then
        --print("Invalid line number: " .. line_number)
        return
    end

    -- Get the lines from the buffer, safeguard against invalid range
    local lines = vim.api.nvim_buf_get_lines(buf_id, line_number - 1, line_number, false)
    if #lines == 0 then
        print("No line content found at line " .. line_number)
        return
    end

    local line_content = lines[1]
    if not line_content then
        print("Failed to get line content for line " .. line_number)
        return
    end

    -- Find the start and end positions of the word within the line content
    local start_pos, end_pos = string.find(line_content, word)
    if start_pos and end_pos then
        -- Add highlight to the word found at the specified positions
        vim.api.nvim_buf_add_highlight(buf_id, -1, color_group, line_number - 1, start_pos - 1, end_pos)
    else
        --print("Word '" .. word .. "' not found in line " .. line_number)
    end
end

function M.debug(msg)
    M.log("DEBUG", msg)
end

function M.info(msg)
    M.log("INFO", msg)
end

function M.warning(msg)
    M.log("WARNING", msg)
end

function M.error(msg)
    M.log("ERROR", msg)
end

function M.get_utc_date_time()
    -- os.time() gets the current time
    -- os.date('!*t') gets the current date table in UTC
    local utc_time = os.date("!%Y-%m-%d %H:%M:%S", os.time())
    return utc_time
end

-- TODO: When log gets a table, print it line by line in the log
function M.print_table(tbl, indent)
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
        local formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            print(formatting)
            M.print_table(v, indent + 1)
        else
            print(formatting .. tostring(v))
        end
    end
end

function M.log(level, msg)
    if M.levels[level] == nil or M.levels[level] < M.current_level then
        return -- Skip logging if the level is below the current threshold
    end

    if log_buf == nil or not vim.api.nvim_buf_is_valid(log_buf) then
        log_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(log_buf, buffer_name)
        vim.api.nvim_buf_set_lines(log_buf, 0, -1, false, {})
        M.add_syntax_highlighting()
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

    -- Update line count for highlighting
    line_count = vim.api.nvim_buf_line_count(log_buf) - 1

    -- Apply highlighting based on the specific keywords
    M.highlight_words(log_buf, line_count, "ERROR", "ErrorMsg")
    M.highlight_words(log_buf, line_count, "WARNING", "WarningMsg")
    M.highlight_words(log_buf, line_count, "INFO", "LogInfo")
    M.highlight_words(log_buf, line_count, "DEBUG", "LogDebug")
end

function M.toggle()
    local current_buf = vim.api.nvim_win_get_buf(0)

    if current_buf == log_buf then
        if prev_buf and vim.api.nvim_buf_is_valid(prev_buf) then
            vim.api.nvim_win_set_buf(0, prev_buf)
        else
            vim.api.nvim_command('enew')
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
