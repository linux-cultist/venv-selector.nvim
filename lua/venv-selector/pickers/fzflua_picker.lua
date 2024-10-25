local config = require("venv-selector.config")
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
    local function draw_icons_for_types(e)
        if
            vim.tbl_contains({
                "cwd",
                "workspace",
                "file",
                "combined",
            }, e.source)
        then
            return "󰥨"
        elseif
            vim.tbl_contains({
                "virtualenvs",
                "hatch",
                "poetry",
                "pyenv",
                "anaconda_envs",
                "anaconda_base",
                "miniconda_envs",
                "miniconda_base",
                "pipx",
            }, e.source)
        then
            return ""
        else
            return "" -- user created venv icon
        end
    end

    local function hl_active_venv(e)
        if e.path == path.current_python_path then
            return ""
        end
        return " "
    end

    return function(entry)
        local icon = entry.icon or ""
        local active_indicator = hl_active_venv(entry)
        local type_icon = draw_icons_for_types(entry)
        local source = config.user_settings.options.show_telescope_search_type and entry.source or ""

        -- Store the raw entry data for selection handling
        return {
            -- Simple tab-separated format for reliable selection parsing
            text = string.format("%s%s\t%s\t%s\t%s", icon, active_indicator, entry.name, type_icon, source),
            entry = entry,
            -- Store original values for selection matching
            name = entry.name,
            path = entry.path,
            type = entry.type,
            source = entry.source,
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

function FzfLuaPicker:open()
    local fzf_lua = require("fzf-lua")
    local search = require("venv-selector.fzf_search")
    local venv = require("venv-selector.venv")

    search.run_search()

    -- Store entries for selection lookup
    local entries_map = {}

    local function process_results(fzf_cb)
        for _, result in ipairs(self.results) do
            local entry = self:make_entry_maker()(result)
            entries_map[entry.text] = entry
            fzf_cb(entry.text)
        end
        fzf_cb(nil) -- EOF
    end

    self.fzf_opts = {
        prompt = "Virtual environments > ",
        fzf_opts = {
            ["--header"] = "Results (ctrl-r to refresh)",
            ["--delimiter"] = "\t",
            ["--with-nth"] = "1,2,3,4", -- Show all columns
            ["--tabstop"] = "4",
        },
        winopts = {
            height = 0.4,
            width = 120,
            row = 0.5,
        },
        actions = {
            ["default"] = function(selected)
                if selected and #selected > 0 then
                    local selected_entry = entries_map[selected[1]]
                    if selected_entry then
                        venv.set_source(selected_entry.source)
                        venv.activate(selected_entry.path, selected_entry.type, true)
                    end
                end
            end,
            ["ctrl-r"] = function()
                self.results = {}
                search.run_search()
                self:open()
            end,
        },
    }

    fzf_lua.fzf_exec(process_results, self.fzf_opts)
end

return FzfLuaPicker
