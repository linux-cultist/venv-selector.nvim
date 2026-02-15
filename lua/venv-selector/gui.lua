-- lua/venv-selector/gui.lua
--
-- Picker orchestration for venv-selector.nvim.
--
-- Responsibilities:
-- - Resolve which picker backend to use (telescope/fzf-lua/snacks/mini-pick/native) based on:
--   - user configuration (options.picker)
--   - runtime availability (whether the picker module can be required)
-- - Load the selected picker implementation from `venv-selector.gui.<picker>` and create an instance.
-- - Delegate environment discovery to the search layer (`search.run_search`) using that picker instance.
--
-- Design notes:
-- - Picker resolution supports an "auto" mode: first installed picker in priority order is selected.
-- - "native" is always considered available (no module requirement).
-- - Errors are surfaced via vim.notify and also logged.
--
-- Conventions:
-- - Picker backends are implemented in `lua/venv-selector/gui/<name>.lua` and must expose `new(opts)`.
-- - Search options (interactive args, callbacks, icon override) are passed through to the search layer.

local log = require("venv-selector.logger")
require("venv-selector.types")

local M = {}


---@type venv-selector.PickerSpec[]
local PICKERS = {
    { name = "telescope", module = "telescope" },
    { name = "fzf-lua",   module = "fzf-lua" },
    { name = "snacks",    module = "snacks" },
    { name = "mini-pick", module = "mini.pick" },
    { name = "native",    module = nil }, -- always available
}

---Notify a user-visible error and also write it to the plugin log.
---@param msg string
local function notify_error(msg)
    vim.notify(msg, vim.log.levels.ERROR, { title = "VenvSelect" })
    log.error(msg)
end

---Return true if `require(module_name)` succeeds.
---@param module_name string
---@return boolean ok
local function is_module_available(module_name)
    local ok = pcall(require, module_name)
    return ok == true
end

---Compute a map of installed pickers for the current runtime.
---@return table<venv-selector.PickerName, boolean> installed
local function get_installed_map()
    ---@type table<venv-selector.PickerName, boolean>
    local installed = {}
    for _, spec in ipairs(PICKERS) do
        if spec.module == nil then
            installed[spec.name] = true
        else
            installed[spec.name] = is_module_available(spec.module)
        end
    end
    return installed
end

---Resolve the picker name given a user setting and installed-map.
---Returns nil if the user requested an invalid or unavailable picker.
---@param picker_setting venv-selector.PickerSetting
---@param installed table<venv-selector.PickerName, boolean>
---@return venv-selector.PickerName|nil resolved
local function resolve_picker_name(picker_setting, installed)
    if picker_setting == "auto" then
        for _, spec in ipairs(PICKERS) do
            if installed[spec.name] then
                return spec.name
            end
        end
        return "native"
    end

    -- validate requested picker
    local known = false
    for _, spec in ipairs(PICKERS) do
        if spec.name == picker_setting then
            known = true
            break
        end
    end

    if not known then
        notify_error(('VenvSelect: invalid picker "%s" selected.'):format(picker_setting))
        return nil
    end

    if not installed[picker_setting] then
        notify_error(("VenvSelect picker is set to %s, but %s is not installed."):format(
            picker_setting, picker_setting
        ))
        return nil
    end

    ---@cast picker_setting venv-selector.PickerName
    return picker_setting
end

---Open the VenvSelect picker UI and start a search.
---This resolves the picker according to user settings and availability.
---@param opts? venv-selector.GuiOpenOpts
function M.open(opts)
    opts = opts or {}

    ---@type venv-selector.PickerSetting
    local picker_setting = require("venv-selector.config").user_settings.options.picker or "auto"

    local installed = get_installed_map()
    local selected = resolve_picker_name(picker_setting, installed)
    if not selected then
        return
    end

    local ok, picker_mod = pcall(require, "venv-selector.gui." .. selected)
    if not ok or not picker_mod or type(picker_mod.new) ~= "function" then
        notify_error(("VenvSelect: failed to load picker implementation '%s'."):format(selected))
        return
    end

    local picker = picker_mod.new(opts)
    require("venv-selector.search").run_search(picker, opts)
end

return M
