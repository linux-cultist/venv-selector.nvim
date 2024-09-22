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
    local self = setmetatable(PickerInterface.new(), FzfLuaPicker)
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
        local fzf_lua = require("fzf-lua")
        fzf_lua.fzf_exec(function(fzf_cb)
            for i, entry in ipairs(self.results) do
                fzf_cb(string.format("%d\t%s", i, entry.text))
            end
            fzf_cb() -- EOF
        end, self.fzf_opts)
    end
end

--- FIXME: Currently will only show results after ctrl+r. search never "completes" and the spinner goes ad infinitum.
--- if you pick a venv after the ctrl + r refresh it will activate but if you try to refresh again it breaks
--- The ctrl + r doesn't actually refresh a new search either, it just shows the results from the previous search
function FzfLuaPicker:open()
    local fzf_lua = require("fzf-lua")
    local search = require("venv-selector.search")

    self.fzf_opts = {
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
                log.debug("Selected: " .. vim.inspect(selected))
                if selected and #selected > 0 then
                    local selection = selected[1]
                    log.debug("Selection: " .. selection)

                    local index = tonumber(selection:match("^(%d+)"))
                    if index then
                        local entry = self.results[index]
                        if entry and entry.entry then
                            log.debug("Activating venv: " .. entry.entry.path)
                            venv.set_source(entry.entry.source)
                            venv.activate(entry.entry.path, entry.entry.type, true)
                        else
                            log.error("Failed to retrieve valid entry data for index: " .. index)
                        end
                    else
                        local path = selection:match("([^%s]+)$")
                        if path then
                            log.debug("Activating venv by path: " .. path)
                            for _, entry in ipairs(self.results) do
                                if entry.entry and entry.entry.path == path then
                                    venv.set_source(entry.entry.source)
                                    venv.activate(path, entry.entry.type, true)
                                    return
                                end
                            end
                            log.error("Failed to find entry data for path: " .. path)
                        else
                            log.error("Failed to extract path from selection: " .. selection)
                        end
                    end
                else
                    log.error("No selection made")
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
                    fzf_cb(string.format("%d\t%s", #self.results, entry.text))
                end
            end,
            on_complete = function()
                fzf_cb()
            end,
        })
    end, self.fzf_opts)
end

return FzfLuaPicker
