local path = require("venv-selector.path")
local utils = require("venv-selector.utils")
local M = {}




function M.activate(settings, python_path)
    if python_path ~= nil then
        local count = 0
        for _, hook in pairs(settings.hooks) do
            count = count + hook(python_path)
        end
        if count == 0 then
            print("No python lsp servers are running. Please open a python file and then select a venv to activate.")
        end
    end
end

function M.activate_from_cache(settings, python_path)
    for _, hook in pairs(settings.hooks) do
        hook(python_path.value)
    end

    path.add(path.get_base(python_path.value))
    local venv = require("venv-selector.venv")
    venv.set_virtual_env(python_path.value)
end

function M.set_virtual_env(python_path)
    local virtual_env = path.get_base(path.get_base(python_path))
    if virtual_env ~= nil then
        vim.fn.setenv("VIRTUAL_ENV", virtual_env)
        dbg("$VIRTUAL_ENV set to " .. virtual_env)
    end
end

return M
