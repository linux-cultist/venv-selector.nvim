M = {}

-- Shows the results from the search in a Telescope picker.
function M.show(results)
    M.results = results
    local finders = require 'telescope.finders'
    local actions_state = require 'telescope.actions.state'
    local entry_display = require 'telescope.pickers.entry_display'

    local displayer = entry_display.create {
        separator = ' ',
        items = {
            { width = 2 },
            { width = 0.95 },
        },
    }
    local finder = finders.new_table {
        results = M.results,
        entry_maker = function(entry)
            entry.value = entry.path
            entry.ordinal = entry.path
            entry.display = function(e)
                return displayer {
                    { e.icon },
                    { e.path },
                }
            end

            return entry
        end,
    }
    local bufnr = vim.api.nvim_get_current_buf()
    local picker = actions_state.get_current_picker(bufnr)
    if picker ~= nil then
        picker:refresh(finder, { reset_prompt = true })
    end
end

return M
