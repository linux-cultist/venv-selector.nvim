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

function M.split_cmd_for_windows(input_str)
    -- Translates the cmd string to a lua table for windows to support different shells.
    -- Spaces in filenames are supported if user is quoting the path with ''.
    -- Each value is also expanded to make sure $HOME etc is translated to a real path.

    local result = {}
    local pattern = [=[(['"])(.-)%1]=] -- pattern to match quoted strings

    -- Remove the quotes and capture quoted parts
    local function add_to_result(quoted, str)
        if quoted then
            table.insert(result, vim.fn.expand(str)) -- Add the string without quotes
        else
            for word in string.gmatch(str, "%S+") do
                table.insert(result, vim.fn.expand(word))
            end
        end
    end

    -- Use gsub to remove quoted strings from input and handle rest
    local unquoted = input_str:gsub(pattern, function(_, str)
        add_to_result(true, str)
        return ""
    end)

    -- Handle remaining parts that are not quoted
    add_to_result(false, unquoted)

    return result
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

function M.check_dependencies_installed()
    local installed, telescope = pcall(require, "telescope")
    if installed == false then
        local message = "VenvSelect requires telescope to be installed."
        vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
        log.error(message)
        return false
    end

    return true
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
