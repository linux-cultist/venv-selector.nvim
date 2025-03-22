local config = require("venv-selector.config")
local gui_utils = require("venv-selector.gui.utils")

local M = {}
M.__index = M

local function get_sorter()
    local filter_type = config.user_settings.options.telescope_filter_type

    if filter_type == "character" then
        return require("telescope.config").values.file_sorter()
    elseif filter_type == "substring" then
        return require("telescope.sorters").get_substr_matcher()
    end
end

function M.new(search_opts)
    local self = setmetatable({ results = {} }, M)

    local opts = {
        prompt_title = "Virtual environments (ctrl-r to refresh)",
        finder = self:make_finder(),
        layout_strategy = "vertical",
        layout_config = {
            height = 0.4,
            width = 120,
            prompt_position = "top",
        },
        cwd = require("telescope.utils").buffer_dir(),

        sorting_strategy = "ascending",
        sorter = get_sorter(),
        attach_mappings = function(bufnr, map)
            map({ "i", "n" }, "<cr>", function()
                local selected_entry = require("telescope.actions.state").get_selected_entry()
                gui_utils.select(selected_entry)
                require("telescope.actions").close(bufnr)
            end)

            map("i", "<C-r>", function()
                self.results = {}
                require("venv-selector.search").run_search(self, search_opts)
            end)

            return true
        end,
    }
    require("telescope.pickers").new({}, opts):find()

    return self
end

function M:make_finder()
    local displayer = require("telescope.pickers.entry_display").create({
        separator = " ",
        items = {
            { width = 2 },
            { width = 90 },
            { width = 2 },
            { width = 20 },
            { width = 0.95 },
        },
    })

    local entry_maker = function(entry)
        local icon = entry.icon
        entry.value = entry.name
        entry.ordinal = entry.path
        entry.display = function(e)
            return displayer({
                {
                    icon,
                    gui_utils.hl_active_venv(entry),
                },
                { e.name },
                {
                    config.user_settings.options.show_telescope_search_type and gui_utils.draw_icons_for_types(
                        entry.source
                    ) or "",
                },
                {
                    config.user_settings.options.show_telescope_search_type and e.source or "",
                },
            })
        end

        return entry
    end

    return require("telescope.finders").new_table({
        results = self.results,
        entry_maker = entry_maker,
    })
end

function M:update_results()
    local bufnr = vim.api.nvim_get_current_buf()
    local picker = require("telescope.actions.state").get_current_picker(bufnr)
    if picker ~= nil then
        picker:refresh(self:make_finder(), { reset_prompt = false })
    end
end

function M:insert_result(result)
    table.insert(self.results, result)
    self:update_results()
end

function M:search_done()
    self.results = gui_utils.remove_dups(self.results)
    gui_utils.sort_results(self.results)

    self:update_results()
end

return M
