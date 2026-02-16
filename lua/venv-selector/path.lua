-- lua/venv-selector/path.lua
--
-- Path + environment state for venv-selector.nvim.
--
-- Responsibilities:
-- - Track currently selected python interpreter and derived venv path.
-- - Mutate the process environment PATH to prioritize the active env (optional).
-- - Provide small path utilities (expand, dirname extraction).
-- - Integrate with dap-python by overriding its python resolution.
--
-- Notes:
-- - This module is intentionally "global" (one active environment at a time).
-- - Per-buffer correctness is handled by venv.lua + cached_venv.lua; this module
--   only applies the global PATH/env mutations and stores global pointers.
-- - PATH mutation is done by prepending the env's bin/Scripts directory and
--   removing the previously prepended directory to avoid stacking.


require("venv-selector.types")

local log = require("venv-selector.logger")

local M = {}

-- ============================================================================
-- Global plugin state (used by public API + picker highlighting)
-- ============================================================================

---@type string|nil
M.current_python_path = nil -- Full path to python executable currently selected.

---@type string|nil
M.current_venv_path = nil -- Derived venv root (typically parent of bin/Scripts).

---@type string|nil
M.current_source = nil -- Optional tag: where the selection came from (cwd/workspace/pipx/etc).

---@type venv-selector.VenvType|nil
M.current_type = nil -- Environment type ("venv", "conda", "uv", etc. depending on caller).

---@type string|nil
local previous_dir = nil -- Last prepended PATH directory (bin/Scripts). Used to remove before adding a new one.

-- OS detection for PATH separator behavior.
local IS_WIN = (package.config:sub(1, 1) == "\\")
local PATH_SEP = IS_WIN and ";" or ":"

-- ============================================================================
-- Internal helpers
-- ============================================================================

---Return true if "activate venv in terminal" behavior is enabled.
---This is a lazy require to avoid config cycles during startup.
---
---@return boolean enabled
local function activate_in_terminal_enabled()
    local ok, cfg = pcall(require, "venv-selector.config")
    if not ok or not cfg or not cfg.user_settings or not cfg.user_settings.options then
        return false
    end
    return cfg.user_settings.options.activate_venv_in_terminal == true
end

---Split a PATH string into a list of entries.
---
---@param path_str string|nil
---@return string[] parts
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

---Join PATH entries back into a PATH string.
---
---@param parts string[]
---@return string path_str
local function join_path(parts)
    return table.concat(parts, PATH_SEP)
end

---Prepend a directory to $PATH and remove duplicates of the same directory.
---Does not touch `previous_dir` (caller manages that state).
---
---@param dir string Directory to prepend (typically .../bin or .../Scripts)
local function prepend_to_path(dir)
    local clean = M.remove_trailing_slash(dir)
    local current = vim.fn.getenv("PATH") or ""
    local parts = split_path(current)

    -- Avoid duplicates by filtering out existing occurrences.
    local filtered = {}
    for _, p in ipairs(parts) do
        if p ~= clean then
            filtered[#filtered + 1] = p
        end
    end

    table.insert(filtered, 1, clean)
    local updated = join_path(filtered)
    vim.fn.setenv("PATH", updated)
    log.trace("Setting new terminal path to: " .. updated)
end

---Remove a directory from $PATH.
---Does not touch `previous_dir` (caller manages that state).
---
---@param dir string Directory to remove
local function remove_from_path(dir)
    local clean = M.remove_trailing_slash(dir)
    local current = vim.fn.getenv("PATH") or ""
    log.trace("Terminal path before venv removal: " .. current)

    local parts = split_path(current)
    local filtered = {}
    for _, p in ipairs(parts) do
        if p ~= clean then
            filtered[#filtered + 1] = p
        end
    end

    local updated = join_path(filtered)
    vim.fn.setenv("PATH", updated)
    log.trace("Terminal path after venv removal: " .. updated)
end

-- ============================================================================
-- Public path helpers
-- ============================================================================

---Remove a trailing slash/backslash from a path (unless path is root).
---
---@param p string
---@return string cleaned
function M.remove_trailing_slash(p)
    if not p or p == "" then
        return p
    end
    if (p:sub(-1) == "/" or p:sub(-1) == "\\") and #p > 1 then
        return p:sub(1, -2)
    end
    return p
end

---Get the directory name (parent path) of a path.
---Example:
---  "/a/b/c" -> "/a/b"
---  "/a/b/c/" -> "/a/b"
---
---@param p string|nil
---@return string|nil base Parent directory path, or nil if not derivable
function M.get_base(p)
    if not p or p == "" then
        return nil
    end

    p = M.remove_trailing_slash(p)

    local base = p:match("(.*[/\\])")
    if not base then
        return nil
    end

    -- Remove trailing slash from match.
    return base:sub(1, -2)
end

---Persist current python selection in module globals and log it.
---Also computes the venv root path from the python executable location.
---
---Expected layout:
---  .../venv/bin/python   (unix)
---  ...\venv\Scripts\python.exe (windows)
---This computes:
---  .../venv
---
---@param python_path string Full path to python executable
function M.save_selected_python(python_path)
    M.current_python_path = python_path

    -- python_path: .../venv/bin/python -> venv root: .../venv
    M.current_venv_path = M.get_base(M.get_base(python_path))

    log.trace('Setting require("venv-selector").python() to \'' .. tostring(M.current_python_path) .. "'")
    log.trace('Setting require("venv-selector").venv() to \'' .. tostring(M.current_venv_path) .. "'")
end

-- ============================================================================
-- PATH mutation API
-- ============================================================================

---Prepend a directory to $PATH, removing any previously-prepended venv dir.
---No-op if terminal activation is disabled.
---
---@param newDir string|nil Directory to add (typically .../bin or .../Scripts)
function M.add(newDir)
    if not activate_in_terminal_enabled() then
        return
    end
    if not newDir or newDir == "" then
        return
    end

    local clean_dir = M.remove_trailing_slash(newDir)

    -- If we already have this at the front from the last activation, no-op.
    if previous_dir == clean_dir then
        log.trace("Path unchanged - already using: " .. clean_dir)
        return
    end

    -- Remove old venv dir first to avoid PATH stacking.
    if previous_dir then
        remove_from_path(previous_dir)
    end

    prepend_to_path(clean_dir)
    previous_dir = clean_dir
end

---Remove the currently active python's directory from $PATH (if known).
---This is derived from `current_python_path` (dirname of the python executable).
function M.remove_current()
    if M.current_python_path then
        local base = M.get_base(M.current_python_path)
        if base then
            M.remove(base)
        end
    end
end

---Remove an explicit directory from $PATH.
---
---@param removalDir string Directory to remove
function M.remove(removalDir)
    if not removalDir or removalDir == "" then
        return
    end
    remove_from_path(removalDir)
end

-- ============================================================================
-- Integrations
-- ============================================================================

---Configure dap-python (if installed) to use the selected python interpreter.
---This overrides dap-python's internal python resolver.
---
---@param python_path string Full path to python executable
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

---Expand ~ and environment variables in paths.
---@param p string
---@return string expanded
function M.expand(p)
    if not p or p == "" then
        return p
    end
    return vim.fn.expand(p)
end

---Get current buffer's file directory.
---@return string|nil dir
function M.get_current_file_directory()
    local name = vim.api.nvim_buf_get_name(0)
    if name == "" then
        return nil
    end
    return vim.fn.fnamemodify(name, ":p:h")
end

return M
