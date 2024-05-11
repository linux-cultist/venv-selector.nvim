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
            { width = 110 },
            { width = 20 },
            { width = 0.95 },
        },
    }

    local title = 'Virtual environments'

    local finder = finders.new_table {
        results = results,
        entry_maker = function(entry)
            entry.value = entry.name
            entry.ordinal = entry.name
            entry.display = function(e)
                return displayer {
                    { e.icon },
                    { e.name },
                    { e.source },
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
                local activated = false
                dbg(selected_entry, "selected_entry")
                if selected_entry ~= nil then
                    activated = venv.activate(settings.hooks, selected_entry)
                    if activated == true then
                        dbg("Venv type '" .. selected_entry.type .. "' activated.")

                        path.add(path.get_base(selected_entry.path))
                        path.update_python_dap(selected_entry.path)
                        path.save_selected_python(selected_entry.path)

                        if selected_entry.type == "anaconda" then
                            venv.unset_env("VIRTUAL_ENV")
                            venv.set_env(selected_entry.path, "CONDA_PREFIX")
                        else
                            venv.unset_env("CONDA_PREFIX")
                            venv.set_env(selected_entry.path, "VIRTUAL_ENV")
                        end
                    end
                end
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
