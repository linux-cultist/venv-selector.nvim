local log = require("venv-selector.logger")

local M = {}

local function resolve_picker()
    local picker = require("venv-selector.config").user_settings.options.picker

    local telescope_installed, _ = pcall(require, "telescope")
    local fzf_lua_installed, _ = pcall(require, "fzf-lua")

    if picker == "auto" then
        if telescope_installed then
            return "telescope"
        elseif fzf_lua_installed then
            return "fzf-lua"
        else
            return "native"
        end
    elseif picker == "telescope" then
        if not telescope_installed then
            local message = "VenvSelect picker is set to telescope, but telescope is not installed."
            vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
            log.error(message)
            return
        end

        return "telescope"
    elseif picker == "fzf-lua" then
        if not fzf_lua_installed then
            local message = "VenvSelect picker is set to fzf-lua, but fzf-lua is not installed."
            vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
            log.error(message)
            return
        end

        return "fzf-lua"
    elseif picker == "native" then
        return "native"
    else
        local message = 'VenvSelect: invalid picker "' .. picker .. '" selected.'
        vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
        log.error(message)
        return
    end
end

function M.open(opts)
    local options = require("venv-selector.config").user_settings.options
    if options.fd_binary_name == nil then
        local message =
            "Cannot find any fd binary on your system. If its installed under a different name, you can set options.fd_binary_name to its name."
        log.error(message)
        vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
        return
    end

    local selected_picker = resolve_picker()
    if selected_picker ~= nil then
        local picker = require("venv-selector.gui." .. selected_picker).new(opts)
        require("venv-selector.search").run_search(picker, opts)
    end
end

return M
