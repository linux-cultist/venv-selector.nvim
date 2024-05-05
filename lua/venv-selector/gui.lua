local venv = require 'venv-selector.venv'
local path = require 'venv-selector.path'

local M = {}

-- Shows the results from the search in a Telescope picker.
function M.show(results, settings)
    local finders = require 'telescope.finders'
    local conf = require('telescope.config').values
    local pickers = require 'telescope.pickers'
    local actions_state = require 'telescope.actions.state'
    local actions = require 'telescope.actions'
    local entry_display = require 'telescope.pickers.entry_display'
    local sorters = require('telescope.sorters')

    local displayer = entry_display.create {
        separator = ' ',
        items = {
            { width = 2 },
            { width = 0.95 },
        },
    }

    local title = 'Virtual environments'

    local finder = finders.new_table {
        results = results,
        entry_maker = function(entry)
            entry.value = entry.path
            entry.ordinal = entry.name
            entry.display = function(e)
                return displayer {
                    { e.icon },
                    { e.name },
                }
            end

            return entry
        end,
    }


    local opts = {
        prompt_title = title,
        finder = finder,
        layout_strategy = 'horizontal',
        layout_config = {
            height = 0.4,
            width = 140,
            prompt_position = 'top',
        },
        cwd = require('telescope.utils').buffer_dir(),

        sorting_strategy = 'ascending',
        sorter = sorters.get_substr_matcher(),
        attach_mappings = function(bufnr, map)
            map('i', '<cr>', function()
                local selected_entry = actions_state.get_selected_entry()
                venv.activate(settings, selected_entry.path)
                path.add(path.get_base(selected_entry.path))
                venv.set_virtual_env(selected_entry.path)
                actions.close(bufnr)
            end)

            map('i', '<C-r>', function()
                local picker = actions_state.get_current_picker(bufnr)
                -- Delay by 10ms to achieve the refresh animation.
                picker:refresh(finder, { reset_prompt = true })
                vim.defer_fn(function()
                    --search.New({}, search.user_settings)
                    --venv.load { force_refresh = true }
                end, 10)
            end)

            return true
        end,
    }
    pickers.new({}, opts):find()
end

return M
