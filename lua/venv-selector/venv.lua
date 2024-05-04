local actions_state = require 'telescope.actions.state'

local M = {}

function M.activate(settings)
    local selected_entry = actions_state.get_selected_entry()

    if selected_entry ~= nil then
        for _, hook in pairs(settings.hooks) do
            hook(selected_entry.path)
        end
    end
end

function M.activate_from_cache(settings, python_path)
    print("Trying to activate from cache")
    print(python_path.value)

    for _, hook in pairs(settings.hooks) do
        hook(python_path.value)
    end
end



return M
