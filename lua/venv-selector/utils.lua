local log = require("venv-selector.logger")

local M = {}

function M.table_has_content(t)
    return next(t) ~= nil
end

function M.merge_user_settings(user_settings)
    log.debug("User plugin settings: ", user_settings.settings, "")
    M.user_settings = vim.tbl_deep_extend("force", M.default_settings, user_settings.settings)
    M.user_settings.detected = {
        system = vim.loop.os_uname().sysname,
    }
    log.debug("Complete user settings:", M.user_settings, "")
end

-- split a string
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

function M.split_cmd_for_windows(str)
    return M.split_string(str)
end

function M.try(table, ...)
    local result = table
    for _, key in ipairs({ ... }) do
        if result then
            result = result[key]
        else
            return nil
        end
    end
    return result
end

function M.print_table(tbl, indent)
    if not indent then
        indent = 0
    end
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

return M
