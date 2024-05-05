local path = require("venv-selector.path")

local M = {}




function M.activate(settings, python_path)
    if python_path ~= nil then
        for _, hook in pairs(settings.hooks) do
            hook(python_path)
        end
    end
end

function M.activate_from_cache(settings, python_path)
    for _, hook in pairs(settings.hooks) do
        hook(python_path.value)
    end
end

function M.set_virtual_env(python_path)
    print(python_path)
    local virtual_env = path.get_base(path.get_base(python_path))
    print(virtual_env)
    vim.fn.setenv("VIRTUAL_ENV", virtual_env)
end

return M
