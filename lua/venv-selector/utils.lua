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

-- Check if a file contains PEP-723 script metadata
function M.has_pep723_metadata(file_path)

    if require("venv-selector.uv").uv_installed ~= true then
        log.debug("Uv not found on system - skipping metadata check.")
        return
    end

    log.debug("Checking PEP-723 metadata for file: '" .. (file_path or "nil") .. "'")

    if not file_path or file_path == "" then
        log.debug("PEP-723 check: file_path is empty or nil")
        return false
    end

    -- Check if file exists and is readable
    local file = io.open(file_path, "r")
    if not file then
        log.debug("PEP-723 check: cannot open file: " .. file_path)
        return false
    end

    local line_count = 0
    local in_script_block = false
    local found_metadata = false

    for line in file:lines() do
        line_count = line_count + 1

        -- Only check first 50 lines for performance
        if line_count > 50 then
            log.debug("PEP-723 check: reached line limit (50), stopping search")
            break
        end

        -- Look for start of script metadata block
        if line:match("^%s*#%s*///%s*script%s*$") then
            log.debug("PEP-723 check: found script block start at line " .. line_count)
            in_script_block = true
        elseif in_script_block and line:match("^%s*#%s*///%s*$") then
            -- Found end of script block
            log.debug("PEP-723 check: found script block end at line " .. line_count)
            found_metadata = true
            break
        elseif in_script_block and line:match("^%s*#%s*dependencies%s*=") then
            -- Found dependencies declaration
            log.debug("PEP-723 check: found dependencies declaration at line " .. line_count)
            found_metadata = true
            break
        end
    end

    file:close()
    log.debug("PEP-723 check result: " .. tostring(found_metadata))
    return found_metadata
end

return M
