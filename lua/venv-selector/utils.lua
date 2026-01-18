local log = require("venv-selector.logger")

local M = {}

---@type table
M.user_settings = {}

---@type table
M.default_settings = {}

---Check if a table has any entries
---@param t table|nil The table to check
---@return boolean true if the table is not empty
function M.table_has_content(t)
    return t ~= nil and next(t) ~= nil
end

---Merge user configuration with plugin defaults
---@param user_settings table User configuration settings
function M.merge_user_settings(user_settings)
    log.debug("User plugin settings: ", user_settings.settings, "")
    M.user_settings = vim.tbl_deep_extend("force", M.default_settings, user_settings.settings or {})
    M.user_settings.detected = {
        system = vim.uv.os_uname().sysname,
    }
    log.debug("Complete user settings:", M.user_settings, "")
end

---Split a string into parts, respecting single and double quotes
---@param str string The string to split
---@return string[] A table of string parts
function M.split_string(str)
    local result = {}
    local buffer = ""
    local in_quotes = false
    local quote_char = nil
    local i = 1

    while i <= #str do
        local c = str:sub(i, i)
        if c == "'" or c == '"' then
            if in_quotes then
                if c == quote_char then
                    in_quotes = false
                    quote_char = nil
                    -- Do not include the closing quote
                else
                    buffer = buffer .. c
                end
            else
                in_quotes = true
                quote_char = c
                -- Do not include the opening quote
            end
        elseif c == " " then
            if in_quotes then
                buffer = buffer .. c
            else
                if #buffer > 0 then
                    table.insert(result, buffer)
                    buffer = ""
                end
            end
        else
            buffer = buffer .. c
        end
        i = i + 1
    end

    if #buffer > 0 then
        table.insert(result, buffer)
    end

    return result
end

---Split a command string for Windows execution
---@param str string The command string
---@return string[] A table of command parts
function M.split_cmd_for_windows(str)
    return M.split_string(str)
end

---Safely access nested table keys
---@param tbl table The table to access
---@param ... string The keys to follow
---@return any|nil The value if found, or nil
function M.try(tbl, ...)
    local result = tbl
    for _, key in ipairs({ ... }) do
        if result and type(result) == "table" then
            result = result[key]
        else
            return nil
        end
    end
    return result
end

---Recursively print a table's contents for debugging
---@param tbl table The table to print
---@param indent? integer The current indentation level
function M.print_table(tbl, indent)
    if not indent then
        indent = 0
    end
    for k, v in pairs(tbl) do
        local formatting = string.rep("  ", indent) .. tostring(k) .. ": "
        if type(v) == "table" then
            print(formatting)
            M.print_table(v, indent + 1)
        else
            print(formatting .. tostring(v))
        end
    end
end

return M