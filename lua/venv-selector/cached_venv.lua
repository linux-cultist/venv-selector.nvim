local config = require("venv-selector.config")
local path = require("venv-selector.path")
local log = require("venv-selector.logger")
local uv2 = require("venv-selector.uv2")

local M = {}

-- Cache file
local cache_file
if config.user_settings and config.user_settings.cache and config.user_settings.cache.file then
    cache_file = path.expand(config.user_settings.cache.file)
else
    -- If you have a default, set it here; otherwise bail out safely.
    -- cache_file = path.expand(config.default_settings.cache.file)
end

-- Ensure the cache directory exists
if cache_file then
    local cache_dir = path.get_base(cache_file)
    if cache_dir and vim.fn.isdirectory(cache_dir) == 0 then
        vim.fn.mkdir(cache_dir, "p")
        log.debug("Created cache directory: " .. cache_dir)
    end
end


-- Track retrieval attempts per key (not global), so multiple workspaces in one session work
local retrieved_for_key = {} ---@type table<string, boolean>

-- Compute a stable key for the current buffer/workspace.
-- Prefer project root from buffer path; fallback to cwd.
local function compute_key(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return vim.fn.getcwd()
    end

    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" then
        return vim.fn.getcwd()
    end

    local dir = vim.fn.fnamemodify(name, ":p:h")
    local root = vim.fs.root(dir, { ".git", "pyproject.toml", "setup.cfg", "setup.py", "requirements.txt" })
    return root or vim.fn.getcwd()
end

function M.get_for_buf(bufnr)
    if config.user_settings.options.enable_cached_venvs ~= true then return nil end
    if not cache_file or cache_file == "" then return nil end
    if vim.fn.filereadable(cache_file) ~= 1 then return nil end

    if vim.api.nvim_buf_is_valid(bufnr) and require("venv-selector.uv2").is_uv_buffer(bufnr) then
        return nil
    end

    local key = compute_key(bufnr)

    local content = vim.fn.readfile(cache_file)
    if not content or not content[1] then return nil end

    local ok, venv_cache = pcall(vim.fn.json_decode, content[1])
    if not ok or not venv_cache then return nil end

    local cleaned = M.clean_stale_entries(venv_cache)
    local v = cleaned[key]
    if not v or not v.value then return nil end

    return v.value, v.type, v.source
end

local function finish(done, activated)
    if done then done(activated == true) end
end

---Handle automatic activation of cached venv (call once at startup or on first python buffer)
---@param done? fun(activated: boolean)
function M.handle_automatic_activation(done)
    if not config.user_settings.options.cached_venv_automatic_activation then
        return finish(done, false)
    end
    M.retrieve(done)
end

---Save current venv to cache for a key (workspace root if possible)
---@param python_path string
---@param venv_type string
---@param bufnr? integer
function M.save(python_path, venv_type, bufnr)
    if config.user_settings.options.enable_cached_venvs ~= true then
        log.debug("Option 'enable_cached_venvs' is false so will not use cache.")
        return
    end

    if not cache_file or cache_file == "" then
        log.debug("No cache file configured; skipping cache save.")
        return
    end

    -- Skip saving UV environments to cache as they are per-buffer and auto-managed
    if venv_type == "uv" then
        log.debug("Skipping cache save for UV environment: " .. python_path)
        return
    end

    local key = compute_key(bufnr or vim.api.nvim_get_current_buf())

    local venv_cache = {
        [key] = {
            value = python_path,
            type = venv_type,
            source = path.current_source,
        },
    }

    local venv_cache_json
    if vim.fn.filereadable(cache_file) == 1 then
        local cached_file = vim.fn.readfile(cache_file)
        if cached_file and cached_file[1] then
            local ok, cached_json = pcall(vim.fn.json_decode, cached_file[1])
            if ok and cached_json then
                local merged_cache = vim.tbl_deep_extend("force", cached_json, venv_cache)
                venv_cache_json = vim.fn.json_encode(merged_cache)
            else
                venv_cache_json = vim.fn.json_encode(venv_cache)
            end
        else
            venv_cache_json = vim.fn.json_encode(venv_cache)
        end
    else
        venv_cache_json = vim.fn.json_encode(venv_cache)
    end

    vim.fn.writefile({ venv_cache_json }, cache_file)
    log.debug("Cache written to file " .. cache_file .. " (key=" .. key .. ")")
    log.debug(("cached_venv.save key=%s py=%s type=%s source=%s buf=%s file=%s"):format(
        tostring(key),
        tostring(python_path),
        tostring(venv_type),
        tostring(path.current_source),
        tostring(bufnr),
        tostring(bufnr and vim.api.nvim_buf_get_name(bufnr) or "")
    ))
end

---Remove entries from cache that point to non-existent python executables
---@param venv_cache table
---@return table
function M.clean_stale_entries(venv_cache)
    local cleaned_cache = {}
    local cache_modified = false

    for key, venv_info in pairs(venv_cache) do
        if venv_info and venv_info.value and vim.fn.filereadable(venv_info.value) == 1 then
            cleaned_cache[key] = venv_info
        else
            if venv_info and venv_info.value then
                log.debug("Removing stale cache entry: " .. venv_info.value .. " (no longer exists)")
            end
            cache_modified = true
        end
    end

    if cache_modified and cache_file and cache_file ~= "" then
        local cleaned_json = vim.fn.json_encode(cleaned_cache)
        vim.fn.writefile({ cleaned_json }, cache_file)
        log.debug("Updated cache file with cleaned entries")
    end

    return cleaned_cache
end

---Retrieve and activate cached venv for current buffer/workspace
---@param done? fun(activated: boolean)
function M.retrieve(done)
    if config.user_settings.options.enable_cached_venvs ~= true then
        log.debug("Option 'enable_cached_venvs' is false so will not use cache.")
        return finish(done, false)
    end

    if not cache_file or cache_file == "" then
        log.debug("No cache file configured; skipping cache retrieval.")
        return finish(done, false)
    end

    local bufnr = vim.api.nvim_get_current_buf()

    -- Skip UV buffers (they manage env themselves)
    if vim.api.nvim_buf_is_valid(bufnr) and uv2.is_uv_buffer(bufnr) then
        log.debug("Skipping cached venv retrieval: uv (PEP 723) buffer detected")
        return finish(done, false)
    end

    local key = compute_key(bufnr)

    if retrieved_for_key[key] then
        log.debug("Cache retrieval already done for key=" .. key .. ", skipping.")
        return finish(done, false)
    end
    retrieved_for_key[key] = true

    if vim.fn.filereadable(cache_file) ~= 1 then
        return finish(done, false)
    end

    local cache_file_content = vim.fn.readfile(cache_file)
    log.debug("Cache retrieved from file " .. cache_file .. " (key=" .. key .. ")")

    if not cache_file_content or not cache_file_content[1] then
        return finish(done, false)
    end

    local ok, venv_cache = pcall(vim.fn.json_decode, cache_file_content[1])
    if not ok or not venv_cache then
        return finish(done, false)
    end

    local cleaned_cache = M.clean_stale_entries(venv_cache)
    local venv_info = cleaned_cache[key]
    if not venv_info or not venv_info.value then
        return finish(done, false)
    end

    -- If already active, do nothing (prevents needless restarts)
    if path.current_python_path == venv_info.value then
        log.debug("Cached venv already active, skipping activation: " .. venv_info.value)
        return finish(done, false)
    end

    local venv = require("venv-selector.venv")
    if venv_info.source ~= nil then
        venv.set_source(venv_info.source)
    end

    log.debug("Activating venv `" .. venv_info.value .. "` from cache (key=" .. key .. ").")

    vim.schedule(function()
        -- Prefer buffer-aware activation (goes through hooks → restart gate)
        if type(venv.activate_for_buffer) == "function" then
            venv.activate_for_buffer(venv_info.value, venv_info.type or "venv", bufnr)
        else
            -- Fallback
            -- venv.activate(venv_info.value, venv_info.type or "venv", false)
        end
        finish(done, true)
    end)
end

return M
