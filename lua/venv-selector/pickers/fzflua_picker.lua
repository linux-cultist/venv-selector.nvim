local config = require("venv-selector.config")
local venv = require("venv-selector.venv")
local PickerInterface = require("venv-selector.pickers.picker_interface")
local path = require("venv-selector.path")
local log = require("venv-selector.logger")

local FzfLuaPicker = {}
FzfLuaPicker.__index = FzfLuaPicker

setmetatable(FzfLuaPicker, {
    __index = PickerInterface,
    __call = function(cls, ...)
        return cls.new(...)
    end,
})

function FzfLuaPicker.new()
    local self = setmetatable({}, FzfLuaPicker)
    return self
end

function FzfLuaPicker:make_entry_maker()
    return function(entry)
        local icon = entry.icon
        local active_indicator = entry.path == path.current_python_path and " " or ""
        local search_type_indicator = config.user_settings.options.show_telescope_search_type
                and self:draw_icons_for_types(entry) .. " " .. entry.source
            or ""

        return {
            text = string.format(
                "%s%s %s %s %s",
                active_indicator,
                icon,
                entry.name,
                search_type_indicator,
                entry.path
            ),
            entry = entry,
        }
    end
end

function FzfLuaPicker:update_results()
    if self.reload_action then
        local opts = {}
        local fzf_lua = require("fzf-lua")
        fzf_lua.fzf_exec(function(fzf_cb)
            for i, entry in ipairs(self.results) do
                fzf_cb(string.format("%d\t%s", i, entry.text))
            end
            fzf_cb() -- EOF
        end, opts)
    end
end

function FzfLuaPicker:open(search_in_progress)
    local fzf_lua = require("fzf-lua")
    local search = require("venv-selector.search")

    local opts = {
        prompt = "Virtual environments > ",
        fzf_opts = {
            ["--header"] = "Virtual environments (ctrl-r to refresh)",
        },
        winopts = {
            height = 0.4,
            width = 120,
            row = 0.5,
        },
        actions = {
            ["default"] = function(selected)
                local entry = selected
                if entry then
                    local path = entry:match("%s([^%s]+)$")
                    if path then
                        venv.set_source(entry.entry.source)
                        venv.activate(path, entry.entry.type, true)
                    end
                end
            end,
            ["ctrl-r"] = function()
                self.results = {}
                self:open()
            end,
        },
    }

    fzf_lua.fzf_exec(function(fzf_cb)
        search.New({
            args = "",
            on_result = function(result)
                if result then
                    local entry = self:make_entry_maker()(result)
                    self:insert_result(entry)
                    fzf_cb(entry.text)
                end
            end,
            on_complete = function()
                fzf_cb(nil)
            end,
        })
    end, opts)
end

return FzfLuaPicker
