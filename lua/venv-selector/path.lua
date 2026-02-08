local utils = require("venv-selector.utils")
local log = require("venv-selector.logger")

local M = {}

---@type string|nil
M.current_python_path = nil
---@type string|nil
M.current_venv_path = nil
---@type string|nil
M.current_source = nil
---@type string|nil
M.current_type = nil

---@type string|nil
local previous_dir = nil

local IS_WIN = (package.config:sub(1, 1) == "\\")
local PATH_SEP = IS_WIN and ";" or ":"

local function activate_in_terminal_enabled()
    -- Lazy require avoids config require-cycle during startup.
    local ok, cfg = pcall(require, "venv-selector.config")
    if not ok or not cfg or not cfg.user_settings or not cfg.user_settings.options then
        return false
    end
    return cfg.user_settings.options.activate_venv_in_terminal == true
end

---@param p string
---@return string
function M.remove_trailing_slash(p)
    if not p or p == "" then return p end
    if (p:sub(-1) == "/" or p:sub(-1) == "\\") and #p > 1 then
        return p:sub(1, -2)
    end
    return p
end

---@param p string|nil
---@return string|nil
function M.get_base(p)
    if not p or p == "" then return nil end
    p = M.remove_trailing_slash(p)

    local base = p:match("(.*[/\\])")
    if not base then
        return nil
    end

    -- remove trailing slash
    return base:sub(1, -2)
end

---@param python_path string
function M.save_selected_python(python_path)
    M.current_python_path = python_path
    -- python_path: .../venv/bin/python -> venv path: .../venv
    M.current_venv_path = M.get_base(M.get_base(python_path))
    log.debug('Setting require("venv-selector").python() to \'' .. tostring(M.current_python_path) .. "'")
    log.debug('Setting require("venv-selector").venv() to \'' .. tostring(M.current_venv_path) .. "'")
end

local function split_path(path_str)
    local out = {}
    if not path_str or path_str == "" then
        return out
    end
    for p in string.gmatch(path_str, "[^" .. PATH_SEP .. "]+") do
        out[#out + 1] = p
    end
    return out
end

local function join_path(parts)
    return table.concat(parts, PATH_SEP)
end

---@param dir string
local function prepend_to_path(dir)
    local clean = M.remove_trailing_slash(dir)
    local current = vim.fn.getenv("PATH") or ""
    local parts = split_path(current)

    -- avoid duplicates: remove existing occurrence
    local filtered = {}
    for _, p in ipairs(parts) do
        if p ~= clean then
            filtered[#filtered + 1] = p
        end
    end

    table.insert(filtered, 1, clean)
    local updated = join_path(filtered)
    vim.fn.setenv("PATH", updated)
    log.debug("Setting new terminal path to: " .. updated)
end

---@param dir string
local function remove_from_path(dir)
    local clean = M.remove_trailing_slash(dir)
    local current = vim.fn.getenv("PATH") or ""
    log.debug("Terminal path before venv removal: " .. current)

    local parts = split_path(current)
    local filtered = {}
    for _, p in ipairs(parts) do
        if p ~= clean then
            filtered[#filtered + 1] = p
        end
    end

    local updated = join_path(filtered)
    vim.fn.setenv("PATH", updated)
    log.debug("Terminal path after venv removal: " .. updated)
end

---@param newDir string|nil
function M.add(newDir)
    if not activate_in_terminal_enabled() then
        return
    end
    if not newDir or newDir == "" then
        return
    end

    local clean_dir = M.remove_trailing_slash(newDir)
    if previous_dir == clean_dir then
        log.debug("Path unchanged - already using: " .. clean_dir)
        return
    end

    if previous_dir then
        remove_from_path(previous_dir)
    end

    prepend_to_path(clean_dir)
    previous_dir = clean_dir
end

function M.remove_current()
    if M.current_python_path then
        local base = M.get_base(M.current_python_path)
        if base then
            M.remove(base)
        end
    end
end

---@param removalDir string
function M.remove(removalDir)
    if not removalDir or removalDir == "" then
        return
    end
    remove_from_path(removalDir)
end

---@param python_path string
function M.update_python_dap(python_path)
    local dap_python_installed, dap_python = pcall(require, "dap-python")
    local dap_installed, _dap = pcall(require, "dap")
    if dap_python_installed and dap_installed then
        log.debug("Setting dap python interpreter to '" .. python_path .. "'")
        dap_python.resolve_python = function()
            return python_path
        end
    end
end

---@return string|nil
function M.get_current_file_directory()
    local opened_filepath = vim.fn.expand("%:p")
    if opened_filepath and opened_filepath ~= "" then
        return M.get_base(opened_filepath)
    end
    return nil
end

---@param p string
---@return string
function M.expand(p)
    return vim.fn.expand(p)
end

return M
