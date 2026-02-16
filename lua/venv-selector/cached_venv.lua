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

---@type venv-selector.CachedVenvTable|nil
local mem_cache = nil

---@type integer|nil
local mem_mtime = nil

---@return string|nil
local function cache_file_path()
    local us = config.user_settings
    local f = us and us.cache and us.cache.file
    if type(f) ~= "string" or f == "" then
        return nil
    end
    return path.expand(f)
end

---@param file string|nil
---@return boolean
local function cache_file_configured(file)
    return type(file) == "string" and file ~= ""
end

---@param file string
---@return string|nil
local function cache_dir_for(file)
    return path.get_base(file)
end

---@param file string|nil
---@return integer|nil
local function get_mtime(file)
    if file == nil or not cache_file_configured(file) then
        return nil
    end
    local t = vim.fn.getftime(file)
    if type(t) ~= "number" or t < 0 then
        return nil
    end
    return t
end

---@param file string|nil
---@return boolean
local function cache_file_exists(file)
    return cache_file_configured(file) and file ~= nil and vim.fn.filereadable(file) == 1
end

---@param file string|nil
local function ensure_cache_dir(file)
    if file == nil or not cache_file_configured(file) then
        return
    end
    local dir = cache_dir_for(file)
    if dir and vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
        log.debug("Created cache directory: " .. dir)
    end
end

---@param done? fun(activated: boolean)
---@param ok boolean
local function finish(done, ok)
    if done then
        done(ok == true)
    end
end

function M.cache_feature_enabled()
    local file = cache_file_path()
    return config.user_settings.options.enable_cached_venvs == true
        and cache_file_configured(file)
end

function M.cache_auto_enabled()
    return M.cache_feature_enabled()
        and config.user_settings.options.cached_venv_automatic_activation == true
end

---@param bufnr integer
---@return boolean
local function valid_py_buf(bufnr)
    return vim.api.nvim_buf_is_valid(bufnr)
        and vim.bo[bufnr].buftype == ""
        and vim.bo[bufnr].filetype == "python"
end

---@param bufnr integer
---@return boolean
local function is_disabled(bufnr)
    return vim.api.nvim_buf_is_valid(bufnr) and vim.b[bufnr].venv_selector_disabled == true
end

---@param bufnr? integer
function M.ensure_buffer_last_venv_activated(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not valid_py_buf(bufnr) then return end
    if is_disabled(bufnr) then return end
    if uv2.is_uv_buffer(bufnr) then return end

    local last = vim.b[bufnr].venv_selector_last_python
    local typ = vim.b[bufnr].venv_selector_last_type or "venv"
    if type(last) ~= "string" or last == "" then return end
    if path.current_python_path == last then return end

    require("venv-selector.venv").activate_for_buffer(last, typ, bufnr, { save_cache = false })
end

---@param file string
---@param tbl venv-selector.CachedVenvTable
---@return boolean
local function write_cache_file(file, tbl)
    ensure_cache_dir(file)

    local ok, json = pcall(vim.fn.json_encode, tbl or {})
    if not ok or not json then
        return false
    end

    vim.fn.writefile({ json }, file)

    mem_cache = tbl
    mem_mtime = get_mtime(file)

    return true
end

---@param file string
---@return venv-selector.CachedVenvTable|nil
local function read_cache_file(file)
    if vim.fn.filereadable(file) ~= 1 then
        return nil
    end

    local content = vim.fn.readfile(file)
    if not content or not content[1] then
        return nil
    end

    local ok, decoded = pcall(vim.fn.json_decode, content[1])
    if not ok or type(decoded) ~= "table" then
        return nil
    end

    ---@cast decoded venv-selector.CachedVenvTable
    return decoded
end

---@param force boolean
---@param file string|nil
---@return venv-selector.CachedVenvTable|nil
local function read_cache(force, file)
    if file == nil then return nil end
    if not cache_file_configured(file) then
        return nil
    end

    local mtime = get_mtime(file)

    if not force and mem_cache and mem_mtime and mtime and mtime == mem_mtime then
        return mem_cache
    end

    if not cache_file_exists(file) then
        mem_cache = nil
        mem_mtime = mtime
        return nil
    end

    local decoded = read_cache_file(file)
    if not decoded then
        mem_cache = nil
        mem_mtime = mtime
        return nil
    end

    mem_cache = decoded
    mem_mtime = mtime
    log.debug("Cache retrieved from file " .. file)

    local cleaned, modified = M.clean_stale_entries(mem_cache)
    if modified then
        write_cache_file(file, cleaned)
        log.debug("Updated cache file with cleaned entries")
    else
        mem_cache = cleaned
    end

    return mem_cache
end

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
        end
    end

    return cleaned, modified
end

---@param python_path string
---@param venv_type venv-selector.VenvType
---@param bufnr? integer
function M.save(python_path, venv_type, bufnr)
    if not M.cache_feature_enabled() then
        return
    end

    if venv_type == "uv" then
        log.debug("Skipping cache save for UV environment: " .. python_path)
        return
    end

    local file = cache_file_path()
    if file == nil or not cache_file_configured(file) then
        return
    end

    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local project_root = require("venv-selector.project_root").key_for_buf(bufnr) or vim.fn.getcwd()

    local existing = read_cache(false, file) or {}

    ---@type venv-selector.CachedVenvInfo
    existing[project_root] = {
        value = python_path,
        type = venv_type,
        source = path.current_source,
    }

    if write_cache_file(file, existing) then
        log.debug("Cache written to file " .. file)
    end
end

---@param bufnr? integer
---@param done? fun(activated: boolean)
function M.retrieve(bufnr, done)
    if not M.cache_feature_enabled() then
        return finish(done, false)
    end

    local file = cache_file_path()
    if not cache_file_configured(file) then
        return finish(done, false)
    end

    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not valid_py_buf(bufnr) then
        return finish(done, false)
    end

    if is_disabled(bufnr) then
        return finish(done, false)
    end

    if uv2.is_uv_buffer(bufnr) then
        return finish(done, false)
    end

    local project_root = require("venv-selector.project_root").key_for_buf(bufnr)
    if not project_root then
        return finish(done, false)
    end

    local cache_tbl = read_cache(false, file)
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

    if vim.fn.filereadable(py) ~= 1 then
        cache_tbl[project_root] = nil
        write_cache_file(file, cache_tbl)
        return finish(done, false)
    end

    local venv = require("venv-selector.venv")
    if venv_info.source ~= nil then
        venv.set_source(venv_info.source)
    end

    vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(bufnr) then return end
        if is_disabled(bufnr) then return end
        venv.activate_for_buffer(py, venv_info.type, bufnr, { save_cache = false })
        finish(done, true)
    end)
end

---@param bufnr? integer
function M.ensure_cached_venv_activated(bufnr)
    if not M.cache_auto_enabled() then
        return
    end

    local file = cache_file_path()
    if file == nil or not cache_file_configured(file) then
        return
    end

    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not valid_py_buf(bufnr) then return end
    if is_disabled(bufnr) then return end
    if uv2.is_uv_buffer(bufnr) then return end

    local project_root = require("venv-selector.project_root").key_for_buf(bufnr)
    if not project_root then return end

    local cache_tbl = read_cache(false, file)
    if not cache_tbl then return end

    local venv_info = cache_tbl[project_root]
    if not venv_info or type(venv_info.value) ~= "string" or venv_info.value == "" then
        return
    end

    if vim.fn.filereadable(venv_info.value) ~= 1 then
        cache_tbl[project_root] = nil
        write_cache_file(file, cache_tbl)
        return
    end

    if path.current_python_path == venv_info.value then
        vim.b[bufnr].venv_selector_cached_applied = venv_info.value
        return
    end

    local venv = require("venv-selector.venv")
    if venv_info.source ~= nil then
        venv.set_source(venv_info.source)
    end

    venv.activate_for_buffer(venv_info.value, venv_info.type, bufnr, { save_cache = false })
    vim.b[bufnr].venv_selector_cached_applied = venv_info.value
end

return M
