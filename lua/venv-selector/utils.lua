local log = require 'venv-selector.logger'

local M = {}

function M.table_has_content(t)
    return next(t) ~= nil
end

function M.merge_user_settings(user_settings)
    log.debug('User plugin settings: ', user_settings.settings, '')
    M.user_settings = vim.tbl_deep_extend('force', M.default_settings, user_settings.settings)
    M.user_settings.detected = {
        system = vim.loop.os_uname().sysname,
    }
    log.debug('Complete user settings:', M.user_settings, '')
end

function M.try(table, ...)
    local result = table
    for _, key in ipairs { ... } do
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
        local message = 'VenvSelect requires telescope to be installed.'
        vim.notify(message, vim.log.levels.ERROR, { title = 'VenvSelect' })
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
        local formatting = string.rep('  ', indent) .. k .. ': '
        if type(v) == 'table' then
            print(formatting)
            M.print_table(v, indent + 1)
        else
            print(formatting .. tostring(v))
        end
    end
end

return M
