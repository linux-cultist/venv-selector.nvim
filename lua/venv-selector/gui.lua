local log = require("venv-selector.logger")

local M = {}

function M.open(opts)
    local options = require("venv-selector.config").user_settings.options
    if options.fd_binary_name == nil then
        local message =
            "Cannot find any fd binary on your system. If its installed under a different name, you can set options.fd_binary_name to its name."
        log.error(message)
        vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
        return
    end

    if require("venv-selector.utils").check_dependencies_installed() == false then
        local message = "Not all required modules are installed."
        log.error(message)
        vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
        return
    end

    local picker = require("venv-selector.gui.telescope").new()
    require("venv-selector.search").run_search(picker, opts)
end

return M
