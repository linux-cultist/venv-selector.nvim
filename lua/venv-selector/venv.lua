local M = {}




function M.activate(settings, selected_entry)
    if selected_entry ~= nil then
        for _, hook in pairs(settings.hooks) do
            hook(selected_entry.path)
        end
    end
end

function M.activate_from_cache(settings, python_path)
    for _, hook in pairs(settings.hooks) do
        hook(python_path.value)
    end
end

return M
