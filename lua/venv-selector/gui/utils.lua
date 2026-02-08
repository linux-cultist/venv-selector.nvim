-- lua/venv-selector/gui/utils.lua
--
-- Shared helper functions for all picker backends (telescope/fzf-lua/snacks/mini/native).
--
-- Goals of this module:
-- - Provide stable, backend-agnostic behaviors:
--   - dedupe rules
--   - consistent sorting rules
--   - icon rendering
--   - active environment highlighting
--   - formatting helpers
-- - Keep picker backends thin: they should mostly render + call into these helpers.
--
-- Notes:
-- - This file intentionally avoids requiring "venv-selector.gui" (the picker resolver)
--   to prevent circular require chains (e.g. telescope -> gui -> telescope).
-- - SearchResult.path is assumed to be a python executable path.

local path = require("venv-selector.path")
local log = require("venv-selector.logger")

local M = {}

-- ============================================================================
-- Types (local, until you move to a central types.lua)
-- ============================================================================

---@class venv-selector.SearchResult
---@field path string
---@field name string
---@field icon? string
---@field type string
---@field source string

---@class venv-selector.Options
---@field show_telescope_search_type? boolean

-- ============================================================================
-- Dedupe
-- ============================================================================

-- Prefer certain sources when multiple results point to the same interpreter.
-- Larger = more preferred.
local DEDUPE_SOURCE_PRIO = {
  workspace = 30,
  file = 20,
}

---Return a stable dedupe key for a result.
---Use the python executable path as the primary identifier.
---@param r venv-selector.SearchResult
---@return string
local function dedupe_key(r)
  -- If path is missing (should not happen), fall back to name.
  return r.path ~= "" and r.path or (r.name or "")
end

---@param r venv-selector.SearchResult
---@return integer
local function dedupe_prio(r)
  return DEDUPE_SOURCE_PRIO[r.source] or 0
end

---@param r venv-selector.SearchResult
---@return boolean
local function is_active(r)
  return M.hl_active_venv(r) ~= nil
end

---Remove duplicates while preserving a sensible “best” candidate for each key.
---Rules:
--- 1) If one of the duplicates is active, keep the active one.
--- 2) Else prefer higher source priority.
--- 3) Else keep first-seen (stable).
---@param results venv-selector.SearchResult[]
---@return venv-selector.SearchResult[]
function M.remove_dups(results)
  local seen = {} ---@type table<string, integer>
  local out = {}  ---@type venv-selector.SearchResult[]

  for _, r in ipairs(results) do
    local k = dedupe_key(r)
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
        local pp, rp = dedupe_prio(prev), dedupe_prio(r)
        if rp > pp then
          out[prev_i] = r
        end
      end
    end
  end

  return out
end

-- ============================================================================
-- Sorting
-- ============================================================================

-- Global sort order for sources. Earlier in this list == higher priority.
local SORT_SOURCE_ORDER = {
  "workspace", "file",
  "pixi", "poetry", "pipenv", "virtualenvs",
  "pyenv", "hatch",
  "anaconda_envs", "anaconda_base",
  "miniconda_envs", "miniconda_base",
  "pipx", "cwd",
}

local SORT_SOURCE_PRIO = (function()
  local prio = {} ---@type table<string, integer>
  local n = #SORT_SOURCE_ORDER
  for i, name in ipairs(SORT_SOURCE_ORDER) do
    prio[name] = n - i + 1
  end
  return prio
end)()

---@param r venv-selector.SearchResult
---@return integer
local function src_prio(r)
  return SORT_SOURCE_PRIO[r.source] or 0
end

---@param p string
---@return string
local function normalize_path(p)
  -- Windows-safe normalization, also makes similarity comparisons consistent.
  return (p or ""):gsub("\\", "/")
end

---Return number of shared prefix path segments.
---Higher means "closer" to the current buffer directory.
---@param p1 string
---@param p2 string
---@return integer
local function path_similarity(p1, p2)
  p1 = normalize_path(p1)
  p2 = normalize_path(p2)

  if p1 == "" or p2 == "" then
    return 0
  end

  local seg1 = vim.split(p1, "/")
  local seg2 = vim.split(p2, "/")

  local count = 0
  for i = 1, math.min(#seg1, #seg2) do
    if seg1[i] == seg2[i] then
      count = count + 1
    else
      break
    end
  end
  return count
end

---Sort results (in-place) for a consistent UX across pickers.
---Sort keys (in priority order):
--- 0) Active venv first
--- 1) Exact match against path.current_python_path
--- 2) Source priority
--- 3) Path similarity (towards current buffer directory)
--- 4) Alphabetical by name
---@param results venv-selector.SearchResult[]
function M.sort_results(results)
  local selected_python = path.current_python_path
  local current_file_dir = vim.fn.expand("%:p:h")

  table.sort(results, function(a, b)
    -- 0) Active marker first
    local a_active = M.hl_active_venv(a) ~= nil
    local b_active = M.hl_active_venv(b) ~= nil
    if a_active ~= b_active then
      return a_active
    end

    -- 1) Selected python match
    local a_is_selected = (a.path == selected_python)
    local b_is_selected = (b.path == selected_python)
    if a_is_selected ~= b_is_selected then
      return a_is_selected
    end

    -- 2) Source priority (higher first)
    local pa, pb = src_prio(a), src_prio(b)
    if pa ~= pb then
      return pa > pb
    end

    -- 3) Path similarity (higher first)
    local sim_a = path_similarity(a.path, current_file_dir)
    local sim_b = path_similarity(b.path, current_file_dir)
    if sim_a ~= sim_b then
      return sim_a > sim_b
    end

    -- 4) Fallback alphabetical
    return (a.name or "") < (b.name or "")
  end)
end

-- ============================================================================
-- Icons / formatting
-- ============================================================================

---Return an icon prefix representing the search/source.
---Respects user overrides:
---  - picker_icons["default"]
---  - picker_icons[source]
---@param source string
---@return string
function M.draw_icons_for_types(source)
  local config = require("venv-selector.config")
  local icons = (config.user_settings and config.user_settings.options and config.user_settings.options.picker_icons) or {}

  if icons["default"] then
    return icons["default"]
  end

  if icons[source] then
    return icons[source]
  end

  -- Built-in defaults
  if source == "cwd" then
    return "🏠"
  elseif source == "workspace" then
    return "💼"
  elseif source == "file" then
    return "📄"
  elseif source == "virtualenvs" then
    return "🐍"
  elseif source == "hatch" then
    return "🥚"
  elseif source == "poetry" then
    return "📜"
  elseif source == "pyenv" then
    return "⚙️"
  elseif vim.tbl_contains({ "anaconda_envs", "anaconda_base" }, source) then
    return "🐊"
  elseif vim.tbl_contains({ "miniconda_envs", "miniconda_base" }, source) then
    return "🔬"
  elseif source == "pipx" then
    return "📦"
  else
    return "🐍"
  end
end

---Highlight group for "active/current venv".
---@param entry venv-selector.SearchResult
---@return string|nil
function M.hl_active_venv(entry)
  local icon_highlight = "VenvSelectActiveVenv"
  if entry.path == path.current_python_path then
    return icon_highlight
  end
  return nil
end

---Format a single entry as a UI string.
---Used by multiple picker backends.
---@param marker string marker column (e.g. "✔" or " ")
---@param source string source key (e.g. "workspace")
---@param name string display name
---@return string
function M.format_result_as_string(marker, source, name)
  local config = require("venv-selector.config")
  local opts = (config.user_settings and config.user_settings.options) or {}

  if opts.show_telescope_search_type then
    return string.format("%s %s %s %s", marker, M.draw_icons_for_types(source), source, name)
  end

  return string.format("%s %s", marker, name)
end

---Return configured picker columns with a safe default.
---@return string[]
function M.get_picker_columns()
  local config = require("venv-selector.config")
  local opts = (config.user_settings and config.user_settings.options) or {}
  return opts.picker_columns or { "marker", "search_icon", "search_name", "search_result" }
end

-- ============================================================================
-- Selection / activation
-- ============================================================================

---Pick the buffer that should receive environment activation.
---Heuristics:
--- 1) Alternate buffer (#) if it is a normal python file
--- 2) Any loaded python file buffer
--- 3) Fallback: current buffer
---@return integer
local function pick_target_python_buf()
  local alt = vim.fn.bufnr("#")
  if alt > 0 and vim.api.nvim_buf_is_valid(alt) then
    if vim.bo[alt].buftype == "" and vim.bo[alt].filetype == "python" then
      return alt
    end
  end

  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b)
        and vim.bo[b].buftype == ""
        and vim.bo[b].filetype == "python"
        and vim.api.nvim_buf_get_name(b) ~= "" then
      return b
    end
  end

  return vim.api.nvim_get_current_buf()
end

---Activate a selected environment result.
---Supports both the newer "activate_for_buffer" API and the older "activate" API.
---@param entry venv-selector.SearchResult|nil
function M.select(entry)
  if entry == nil then
    return
  end

  local venv = require("venv-selector.venv")
  venv.set_source(entry.source)

  local bufnr = pick_target_python_buf()

  if type(venv.activate_for_buffer) == "function" then
    venv.activate_for_buffer(entry.path, entry.type, bufnr, { save_cache = true })
  else
    venv.activate(entry.path, entry.type, true)
  end
end

return M
