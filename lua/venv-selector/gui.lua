local config = require("venv-selector.config")

--- FIXME: I need to figure out how to get the picker from the user settings
--- but I keep running into issues where the user settings are not merged before
--- the code tries to access the merged table of settings.

local guiPicker = "fzf-lua"
local M = {}

if guiPicker == "telescope" then
    local TelescopePicker = require("venv-selector.pickers.telescope_picker")
    M = TelescopePicker:new()
elseif guiPicker == "fzf-lua" then
    local FzfLuaPicker = require("venv-selector.pickers.fzflua_picker")
    M = FzfLuaPicker:new()
else
    vim.notify('Invalid picker setting, please select one of "telescope" or "fzf-lua"', vim.log.levels.ERROR)
    vim.notify("The currently selected picker is: " .. guiPicker, vim.log.levels.ERROR)
end

return M
