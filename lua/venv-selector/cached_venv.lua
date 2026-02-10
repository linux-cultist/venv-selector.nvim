-- lua/venv-selector/cached_venv.lua
--
-- Persistent venv cache for venv-selector.nvim.
--
-- Responsibilities:
-- - Persist the selected python executable per project root in a JSON file.
-- - Restore a cached selection automatically (if enabled) on buffer lifecycle events.
-- - Maintain a session-local “last selection per buffer” memory that restores without disk I/O.
-- - Skip uv (PEP 723) buffers entirely: uv environments are derived from metadata and managed by uv2.lua.
-- - Clean stale cache entries that point to missing python executables.
--
-- Design notes:
-- - Cache keys are project roots as returned by `project_root.key_for_buf(bufnr)`; fallback to cwd for saving.
-- - Automatic activation is gated by:
--   - options.enable_cached_venvs
--   - cache.file configured
--   - options.cached_venv_automatic_activation
-- - `ensure_cached_venv_activated()` is intended for frequent calls (BufEnter/BufWinEnter). It performs
--   a cheap “already active?” check before switching environments.
-- - Writes are small JSON blobs stored as a single-line file (one JSON object).
--
-- Conventions:
-- - CachedVenvInfo.value is an absolute path to a python executable (interpreter).
-- - CachedVenvTable is keyed by project_root: table<string, CachedVenvInfo>.
-- - Buffer-local fields used:
--   - b:venv_selector_last_python / b:venv_selector_last_type
--   - b:venv_selector_cached_applied (tracks what cache was last applied to this buffer)

require("venv-selector.types")

local config = require("venv-selector.config")
local path = require("venv-selector.path")
local log = require("venv-selector.logger")
local uv2 = require("venv-selector.uv2")

local M = {}


local cache_file

if config.user_settings
    and config.user_settings.cache
    and config.user_settings.cache.file
then
    cache_file = path.expand(config.user_settings.cache.file)
end

---@type venv-selector.CachedVenvTable|nil
local mem_cache = nil

---@type integer|nil
local mem_mtime = nil

local function get_mtime()
    if not cache_file or cache_file == "" then return nil end
    local t = vim.fn.getftime(cache_file)
    if type(t) ~= "number" or t < 0 then return nil end
    return t
end


-- Ensure cache directory exists
if cache_file and cache_file ~= "" then
    local cache_dir = path.get_base(cache_file)
    if cache_dir and vim.fn.isdirectory(cache_dir) == 0 then
        vim.fn.mkdir(cache_dir, "p")
        log.debug("Created cache directory: " .. cache_dir)
    end
end

---Invoke a completion callback with a boolean `activated` value, preserving legacy behavior.
---@param done? fun(activated: boolean)
---@param ok boolean
local function finish(done, ok)
    if done then done(ok == true) end
end

---Cache storage feature enabled (read/write allowed).
---@return boolean ok
local function cache_feature_enabled()
    if config.user_settings.options.enable_cached_venvs ~= true then
        log.debug("Option 'enable_cached_venvs' is false so will not use cache.")
        return false
    end
    if not cache_file or cache_file == "" then
        log.debug("Cache disabled: cache file not configured.")
        return false
    end
    return true
end

---Automatic cache activation enabled (auto restore on events).
---@return boolean ok
local function cache_auto_enabled()
    if not cache_feature_enabled() then
        return false
    end
    if config.user_settings.options.cached_venv_automatic_activation ~= true then
        return false
    end
    return true
end

---Return true if the buffer is a normal on-disk python buffer (not a special buftype).
---@param bufnr integer
---@return boolean ok
local function valid_py_buf(bufnr)
    return vim.api.nvim_buf_is_valid(bufnr)
        and vim.bo[bufnr].buftype == ""
        and vim.bo[bufnr].filetype == "python"
end

---Ensure the last venv used in this buffer is active.
---This is session-local memory only (no disk I/O, no persistent cache dependency).
---
---Notes:
--- - Skips uv buffers; those are managed by uv2.lua.
--- - Does not write cache again (save_cache=false).
---@param bufnr? integer
function M.ensure_buffer_last_venv_activated(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not valid_py_buf(bufnr) then
        return
    end

    -- uv buffers are handled by uv2
    if uv2.is_uv_buffer(bufnr) then
        return
    end

    local last = vim.b[bufnr].venv_selector_last_python
    local typ = vim.b[bufnr].venv_selector_last_type or "venv"
    if type(last) ~= "string" or last == "" then
        return
    end

    -- If already active globally, just stop.
    if path.current_python_path == last then
        return
    end

    require("venv-selector.venv").activate_for_buffer(last, typ, bufnr, { save_cache = false })
end

---Encode and write the cache table to disk.
---@param tbl venv-selector.CachedVenvTable
---@return boolean ok
local function write_cache(tbl)
    local ok, json = pcall(vim.fn.json_encode, tbl or {})
    if not ok or not json then
        return false
    end
    vim.fn.writefile({ json }, cache_file)

    mem_cache = tbl
    mem_mtime = get_mtime()

    return true
end


---Read and decode the cache JSON file (memoized).
---@param force? boolean
---@return venv-selector.CachedVenvTable|nil
local function read_cache(force)
    if not cache_file or cache_file == "" then
        return nil
    end

    local mtime = get_mtime()
    if not force and mem_cache and mem_mtime and mtime and mtime == mem_mtime then
        return mem_cache
    end

    if vim.fn.filereadable(cache_file) ~= 1 then
        mem_cache = nil
        mem_mtime = mtime
        return nil
    end

    local content = vim.fn.readfile(cache_file)
    if not content or not content[1] then
        mem_cache = nil
        mem_mtime = mtime
        return nil
    end

    local ok, decoded = pcall(vim.fn.json_decode, content[1])
    if not ok or type(decoded) ~= "table" then
        mem_cache = nil
        mem_mtime = mtime
        return nil
    end

    mem_cache = decoded
    mem_mtime = mtime
    log.debug("Cache retrieved from file " .. cache_file)

    -- One-time full cleanup on load (keeps hot paths O(1) later).
    local cleaned, modified = M.clean_stale_entries(mem_cache)
    if modified then
        write_cache(cleaned) -- updates mem_cache + mem_mtime
        log.debug("Updated cache file with cleaned entries")
    else
        mem_cache = cleaned
    end

    return mem_cache
end

---Remove entries that point to missing python executables.
---@param cache_tbl venv-selector.CachedVenvTable|any
---@return venv-selector.CachedVenvTable cleaned
---@return boolean modified
function M.clean_stale_entries(cache_tbl)
    if type(cache_tbl) ~= "table" then
        return {}, false
    end

    ---@type venv-selector.CachedVenvTable
    local cleaned = {}
    local modified = false

    for root, info in pairs(cache_tbl) do
        local val = info and info.value
        if type(val) == "string" and vim.fn.filereadable(val) == 1 then
            ---@cast info venv-selector.CachedVenvInfo
            cleaned[root] = info
        else
            modified = true
            if val then
                log.debug("Removing stale cache entry: " .. tostring(val))
            end
        end
    end

    return cleaned, modified
end

---Attempt automatic activation of the cached venv for the current buffer.
---Respects option: `cached_venv_automatic_activation`.
---@param done? fun(activated: boolean) Callback called when activation attempt finishes
function M.handle_automatic_activation(done)
    if not cache_auto_enabled() then return finish(done, false) end

    local bufnr = vim.api.nvim_get_current_buf()
    M.retrieve(bufnr, done)
end

---Save the selected interpreter to cache under the project root for `bufnr`.
---No-op if caching is disabled.
---Skips saving for uv (PEP 723) environments.
---@param python_path string Absolute path to python executable
---@param venv_type venv-selector.VenvType Environment type
---@param bufnr? integer Buffer used to compute project root (defaults to current buffer)
function M.save(python_path, venv_type, bufnr)
    if not cache_feature_enabled() then return end

    if venv_type == "uv" then
        log.debug("Skipping cache save for UV environment: " .. python_path)
        return
    end

    bufnr = bufnr or vim.api.nvim_get_current_buf()

    local project_root =
        require("venv-selector.project_root").key_for_buf(bufnr)
        or vim.fn.getcwd()

    local existing = read_cache() or {}

    ---@type venv-selector.CachedVenvInfo
    existing[project_root] = {
        value = python_path,
        type = venv_type,
        source = path.current_source,
    }

    if write_cache(existing) then
        log.debug("Cache written to file " .. cache_file)
    end
end

---Retrieve and activate cached venv for the given buffer's project root.
---No-op for uv (PEP 723) buffers.
---@param bufnr? integer Buffer to use for project root lookup (defaults to current buffer)
---@param done? fun(activated: boolean) Callback called after activation attempt completes
function M.retrieve(bufnr, done)
    if not cache_auto_enabled() then
        return finish(done, false)
    end

    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not valid_py_buf(bufnr) then
        return finish(done, false)
    end

    if uv2.is_uv_buffer(bufnr) then
        log.debug("Skipping cached venv retrieval: uv buffer detected")
        return finish(done, false)
    end

    local project_root = require("venv-selector.project_root").key_for_buf(bufnr)
    if not project_root then
        log.debug("Cache lookup skipped: project_root=nil for bufnr=" .. tostring(bufnr))
        return finish(done, false)
    end

    local cache_tbl = read_cache()
    if not cache_tbl then
        return finish(done, false)
    end

    local venv_info = cache_tbl[project_root]
    if not venv_info then
        return finish(done, false)
    end

    local py = venv_info.value
    if type(py) ~= "string" or py == "" then
        return finish(done, false)
    end

    -- Per-root stale cleanup (cheap; avoids full clean on every call).
    if vim.fn.filereadable(py) ~= 1 then
        cache_tbl[project_root] = nil
        write_cache(cache_tbl)
        log.debug("Removed stale cache entry for project_root=" .. project_root)
        return finish(done, false)
    end

    local venv = require("venv-selector.venv")
    if venv_info.source ~= nil then
        venv.set_source(venv_info.source)
    end

    log.debug(("Activating venv `%s` from cache for project_root=%s"):format(py, project_root))

    vim.schedule(function()
        venv.activate_for_buffer(py, venv_info.type, bufnr, { save_cache = false })
        finish(done, true)
    end)
end

---Ensure the cached venv for this buffer is active (use on BufEnter/BufWinEnter).
---@param bufnr? integer
function M.ensure_cached_venv_activated(bufnr)
    if not cache_auto_enabled() then return end

    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not valid_py_buf(bufnr) then
        return
    end

    if uv2.is_uv_buffer(bufnr) then
        return
    end

    local project_root = require("venv-selector.project_root").key_for_buf(bufnr)
    if not project_root then
        return
    end

    local cache_tbl = read_cache()
    if not cache_tbl then
        return
    end

    local cleaned = M.clean_stale_entries(cache_tbl)
    local venv_info = cleaned[project_root]
    if not venv_info or type(venv_info.value) ~= "string" or venv_info.value == "" then
        return
    end

    -- If already active globally, just mark buffer and stop.
    if path.current_python_path == venv_info.value then
        vim.b[bufnr].venv_selector_cached_applied = venv_info.value
        return
    end

    -- If we already applied this for this buffer, but global differs, we must switch back.
    local applied = vim.b[bufnr].venv_selector_cached_applied
    if applied == venv_info.value and path.current_python_path ~= venv_info.value then
        -- fallthrough (must activate)
    end

    local venv = require("venv-selector.venv")
    if venv_info.source ~= nil then
        venv.set_source(venv_info.source)
    end

    log.debug(("ensure_cached_venv_activated: switching to `%s` for project_root=%s"):format(
        venv_info.value, project_root
    ))

    -- Do it synchronously so state is correct immediately (picker markers, etc.)
    venv.activate_for_buffer(
        venv_info.value,
        venv_info.type,
        bufnr,
        { save_cache = false }
    )

    vim.b[bufnr].venv_selector_cached_applied = venv_info.value
end

return M
