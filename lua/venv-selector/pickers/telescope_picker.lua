local config = require("venv-selector.config")
local venv = require("venv-selector.venv")
local Picker = require("venv-selector.pickers.picker_interface")

local TelescopePicker = setmetatable({}, Picker)
TelescopePicker.__index = TelescopePicker

---@diagnostic disable-next-line: duplicate-set-field
function TelescopePicker.new()
    local self = setmetatable(Picker.new(), TelescopePicker)
    return self
end

---@diagnostic disable-next-line: duplicate-set-field
function TelescopePicker:get_sorter()
    local sorters = require("telescope.sorters")
    local conf = require("telescope.config").values

    local choices = {
        ["character"] = function()
            return conf.file_sorter()
        end,
        ["substring"] = function()
            return sorters.get_substr_matcher()
        end,
    }

    return choices[config.user_settings.options.telescope_filter_type]
end

---@diagnostic disable-next-line: duplicate-set-field
function TelescopePicker:make_entry_maker()
    local entry_display = require("telescope.pickers.entry_display")

    local displayer = entry_display.create({
        separator = " ",
        items = {
            { width = 2 },
            { width = 90 },
            { width = 2 },
            { width = 20 },
            { width = 0.95 },
        },
    })

    return function(entry)
        local icon = entry.icon
        entry.value = entry.name
        entry.ordinal = entry.path
        entry.display = function(e)
            return displayer({
                {
                    icon,
                    self:hl_active_venv(e),
                },
                { e.name },
                {
                    config.user_settings.options.show_telescope_search_type and self:draw_icons_for_types(e) or "",
                },
                {
                    config.user_settings.options.show_telescope_search_type and e.source or "",
                },
            })
        end

        return entry
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function TelescopePicker:update_results()
    local finders = require("telescope.finders")
    local actions_state = require("telescope.actions.state")

    local finder = finders.new_table({
        results = self.results,
        entry_maker = self:make_entry_maker(),
    })

    local bufnr = vim.api.nvim_get_current_buf()
    local picker = actions_state.get_current_picker(bufnr)
    if picker ~= nil then
        picker:refresh(finder, { reset_prompt = false })
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function TelescopePicker:open(in_progress)
    local finders = require("telescope.finders")
    local pickers = require("telescope.pickers")
    local actions_state = require("telescope.actions.state")
    local actions = require("telescope.actions")

    local title = "Virtual environments (ctrl-r to refresh)"

    if in_progress == false then
        self:sort_results()
    end

    local finder = finders.new_table({
        results = self.results,
        entry_maker = self:make_entry_maker(),
    })

    local opts = {
        prompt_title = title,
        finder = finder,
        layout_strategy = "vertical",
        layout_config = {
            height = 0.4,
            width = 120,
            prompt_position = "top",
        },
        cwd = require("telescope.utils").buffer_dir(),

        sorting_strategy = "ascending",
        sorter = self:get_sorter()(),
        attach_mappings = function(bufnr, map)
            map({ "i", "n" }, "<cr>", function()
                local selected_entry = actions_state.get_selected_entry()
                if selected_entry ~= nil then
                    venv.set_source(selected_entry.source)
                    venv.activate(selected_entry.path, selected_entry.type, true)
                end
                actions.close(bufnr)
            end)

            map("i", "<C-r>", function()
                self.results = {}
                local search = require("venv-selector.search")
                search.New(nil)
            end)

            return true
        end,
    }
    pickers.new({}, opts):find()
end

return TelescopePicker
