-- lua/venv-selector/gui/utils.lua
--
-- GUI helper utilities for venv-selector.nvim pickers.
--
-- Responsibilities:
-- - Provide common result processing for all picker backends:
--   - deduplicate streamed SearchResult items with simple source-priority rules
--   - sort results so active/selected and most relevant entries appear first
-- - Provide shared rendering helpers:
--   - source/type icons for common search origins
--   - marker highlight detection for the currently active interpreter
--   - formatted display strings and configured picker column order
-- - Provide a shared selection action:
--   - choose a target python buffer (prefer alternate or any loaded python buffer)
--   - activate the chosen interpreter for that buffer via venv.lua
--
-- Design notes:
-- - Deduplication prefers:
--   - active item over inactive item
--   - otherwise, higher-priority sources (currently: workspace > file > others)
-- - Sorting is stable by intent, not by implementation:
--   - active first
--   - then currently selected interpreter
--   - then source priority (workspace/file/.../cwd)
--   - then similarity to current file directory (prefix segment match)
--   - then name (alphabetical)
-- - The selection function delegates to `venv.activate_for_buffer` when available to preserve
--   buffer-scoped behavior; falls back to `venv.activate` otherwise.
--
-- Conventions:
-- - SearchResult shape is defined in search.lua and is treated as:
--   { path, name, icon, type, source } (with additional fields allowed).
-- - Highlight group used for active marker is "VenvSelectActiveVenv".
-- - Picker column order defaults to: marker, search_icon, search_name, search_result.

local path = require("venv-selector.path")
local log = require("venv-selector.logger")

---@class venv-selector.Options
---@field show_telescope_search_type? boolean

local M = {}

---@class SearchResult
---@field path string
---@field name string
---@field icon string
---@field type string
---@field source string
---@field text? string

---Remove duplicate results by path/name key, preferring active entries and higher source priority.
---@param results SearchResult[]
---@return SearchResult[] deduped
function M.remove_dups(results)
    ---@type table<string, integer>
    local seen = {}
    ---@type SearchResult[]
    local out = {}

    local SOURCE_PRIO = {
        workspace = 30,
        file = 20
    }

    ---Return a stable deduplication key for a result.
    ---Prefer path; fall back to name.
    ---@param r SearchResult
    ---@return string k
    local function key(r)
        return r.path or r.name
    end

    ---Return a numeric priority for a result's source.
    ---@param r SearchResult
    ---@return integer p
    local function prio(r)
        return SOURCE_PRIO[r.source] or 0
    end

    ---Return true if the result corresponds to the currently active interpreter.
    ---@param r SearchResult
    ---@return boolean active
    local function is_active(r)
        return M.hl_active_venv(r) ~= nil
    end

    for _, r in ipairs(results) do
        local k = key(r)
        local prev_i = seen[k]

        if not prev_i then
            out[#out + 1] = r
            seen[k] = #out
        else
            local prev = out[prev_i]

            local prev_active, r_active = is_active(prev), is_active(r)
            if prev_active ~= r_active then
                if r_active then
                    out[prev_i] = r
                end
            else
                -- both active or both not active: prefer higher source priority
                local pp, rp = prio(prev), prio(r)
                if rp > pp then
                    out[prev_i] = r
                end
            end
        end
    end

    return out
end

---Sort results in-place to prioritize active/selected entries and more relevant sources/paths.
---@param results SearchResult[]
function M.sort_results(results)
    local order = {
        "workspace", "file",
        "pixi", "poetry", "pipenv", "
