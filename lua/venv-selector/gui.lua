local log = require("venv-selector.logger")

local M = {}

local function resolve_picker()
    local picker = require("venv-selector.config").user_settings.options.picker

    -- Picker configurations in priority order
    local pickers = {
        { name = "telescope", module = "telescope" },
        { name = "fzf-lua",   module = "fzf-lua" },
        { name = "snacks",    module = "snacks" },
        { name = "mini-pick", module = "mini.pick" },
        { name = "native",    module = nil }, -- native doesn't require a module
    }

    -- Check installation status for all pickers
    local picker_status = {}
    for _, p in ipairs(pickers) do
        if p.module then
            picker_status[p.name] = pcall(require, p.module)
        else
            picker_status[p.name] = true -- native is always available
        end
    end

    if picker == "auto" then
        -- Find first installed picker in priority order
        for _, p in ipairs(pickers) do
            if picker_status[p.name] then
                return p.name
            end
        end
        return "native" -- fallback
    elseif picker == "native" then
        return "native"
    else
        -- Validate specific picker choice
        local picker_found = false
        for _, p in ipairs(pickers) do
            if p.name == picker then
                picker_found = true
                if not picker_status[picker] then
                    local message = "VenvSelect picker is set to " ..
                        picker .. ", but " .. picker .. " is not installed."
                    vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
                    log.error(message)
                    return
                end
                return picker
            end
        end

        -- Invalid picker name
        if not picker_found then
            local message = 'VenvSelect: invalid picker "' .. picker .. '" selected.'
            vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
            log.error(message)
            return
        end
    end
end

function M.open(opts)
    -- Check Neovim version requirement
    local req_version = "0.11"
    if vim.fn.has("nvim-" .. req_version) ~= 1 then
        vim.notify(
            "venv-selector.nvim now requires neovim " .. req_version .. " or higher (your version is " ..
            vim.version().major .. "." .. vim.version().minor .. ").",
            vim.log.levels.ERROR,
            { title = "VenvSelector" }
        )
        return M
    end


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
