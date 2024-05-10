local config = require("venv-selector.config")

local M = {}

function M.table_empty(t)
    return next(t) == nil
end

function M.dbg(msg, name)
    if config.user_settings.options.debug == false or msg == nil then
        return
    end

    if type(msg) == 'string' or type(msg) == 'number' then
        if name ~= nil then
            print(name .. ":", msg)
        else
            print(msg)
        end
    elseif type(msg) == 'table' then
        if name ~= nil then
            print(name .. ":")
        end
        M.print_table(msg, 2)
    elseif type(msg) == 'boolean' then
        print(tostring(msg))
    else
        print('Unhandled message type to dbg: message type is ' .. type(msg))
    end
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
    local installed, telescope = pcall(require, 'telescope')
    if installed == false then
        print("VenvSelect requires telescope to be installed.")
        return false
    end

    return true
end

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

return M
