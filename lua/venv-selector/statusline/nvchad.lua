local M = {}

function M.render() -- call this function from ~/.config/nvim/lua/chadrc.lua
    if vim.bo.filetype ~= "python" then
        return ""
    end

    local statusline_func = require("venv-selector.config").user_settings.options.statusline_func.nvchad
    if statusline_func ~= nil then
        return statusline_func()
    end

    local venv_path = require("venv-selector").venv()
    if not venv_path or venv_path == "" then
        return nil
    end

    local venv_name = vim.fn.fnamemodify(venv_path, ":t")
    if not venv_name then
        return ""
    end

    local output = "󰈺 " .. venv_name .. " "
    return output
end

return M
