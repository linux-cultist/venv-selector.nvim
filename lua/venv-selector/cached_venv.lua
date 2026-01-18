local config = require("venv-selector.config")
local path = require("venv-selector.path")
local log = require("venv-selector.logger")
local uv2 = require("venv-selector.uv2")

local cache_file
if config.user_settings and config.user_settings.cache and config.user_settings.cache.file then
    cache_file = path.expand(config.user_settings.cache.file)
else
    -- Fall back to default cache file if the user setting is not present
    cache_file = path.expand(config.default_settings.cache.file)
end

-- Ensure the cache directory exists
local cache_dir = path.get_base(cache_file)
if cache_dir and vim.fn.isdirectory(cache_dir) == 0 then
    vim.fn.mkdir(cache_dir, "p")
    log.debug("Created cache directory: " .. cache_dir)
end


local cache_retrieval_done = false

local M = {}

---Handle automatic activation of cached venv on startup
---@param done? fun(activated: boolean) Callback called when activation attempt finishes
function M.handle_automatic_activation(done)
    -- done: function() called when the activation attempt finishes (success or not)
    if not config.user_settings.options.cached_venv_automatic_activation then
        if done then done(false) end
        return
    end

    -- M.retrieve must accept a callback and call it once when it finishes.
    M.retrieve(function(activated)
        if done then done(activated == true) end
    end)
end

---Save current venv to cache for the current working directory
---@param python_path string Path to the python executable
---@param venv_type string Type of the virtual environment
function M.save(python_path, venv_type)
    if config.user_settings.options.enable_cached_venvs ~= true then
        log.debug("Option 'enable_cached_venvs' is false so will not use cache.")
        return
    end

    -- Skip saving UV environments to cache as they are managed automatically
    if venv_type == "uv" then
        log.debug("Skipping cache save for UV environment: " .. python_path)
        return
    end


    local venv_cache = {
        [vim.fn.getcwd()] = {
            value = python_path,
            type = venv_type,
            source = path.current_source,
        },
    }

    local venv_cache_json = nil

    if vim.fn.filereadable(cache_file) == 1 then
        -- if cache file exists and is not empty read it and merge it with the new cache
        local cached_file = vim.fn.readfile(cache_file)
        if cached_file ~= nil and cached_file[1] ~= nil then
            local cached_json = vim.fn.json_decode(cached_file[1])
            local merged_cache = vim.tbl_deep_extend("force", cached_json, venv_cache)
            venv_cache_json = vim.fn.json_encode(merged_cache)
        else
            venv_cache_json = vim.fn.json_encode(venv_cache)
        end
    else
        venv_cache_json = vim.fn.json_encode(venv_cache)
    end

    vim.fn.writefile({ venv_cache_json }, cache_file)
    log.debug("Cache written to file " .. cache_file)
end

---Remove entries from cache that point to non-existent python executables
---@param venv_cache table The loaded cache table
---@return table The cleaned cache table
function M.clean_stale_entries(venv_cache)
    local cleaned_cache = {}
    local cache_modified = false

    for cwd, venv_info in pairs(venv_cache) do
        if vim.fn.filereadable(venv_info.value) == 1 then
            cleaned_cache[cwd] = venv_info
        else
            log.debug("Removing stale cache entry: " .. venv_info.value .. " (no longer exists)")
            cache_modified = true
        end
    end

    -- Save cleaned cache if modified
    if cache_modified then
        local cleaned_json = vim.fn.json_encode(cleaned_cache)
        vim.fn.writefile({ cleaned_json }, cache_file)
        log.debug("Updated cache file with cleaned entries")
    end

    return cleaned_cache
end

---Retrieve and activate the cached venv for the current working directory
---@param done? fun(activated: boolean) Callback called when retrieval/activation finishes
function M.retrieve(done)
    local function finish(activated)
        cache_retrieval_done = true
        if done then done(activated == true) end
    end

    if config.user_settings.options.enable_cached_venvs ~= true then
        log.debug("Option 'enable_cached_venvs' is false so will not use cache.")
        return finish(false)
    end

    if cache_retrieval_done then
        log.debug("Cache retrieval already done in this session, skipping.")
        return finish(false)
    end

    -- NEW: skip cached venvs for uv / PEP 723 buffers
    local bufnr = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_is_valid(bufnr) and uv2.is_uv_buffer(bufnr) then
        log.debug("Skipping cached venv retrieval: uv (PEP 723) buffer detected")
        return finish(false)
    end


    if vim.fn.filereadable(cache_file) ~= 1 then
        return finish(false)
    end

    local cache_file_content = vim.fn.readfile(cache_file)
    log.debug("Cache retrieved from file " .. cache_file)

    if not cache_file_content or not cache_file_content[1] then
        return finish(false)
    end

    local venv_cache = vim.fn.json_decode(cache_file_content[1])
    if not venv_cache then
        return finish(false)
    end

    local cleaned_cache = M.clean_stale_entries(venv_cache)

    local cwd = vim.fn.getcwd()
    local venv_info = cleaned_cache[cwd]
    if not venv_info then
        return finish(false)
    end

    local venv = require("venv-selector.venv")
    if venv_info.source ~= nil then
        venv.set_source(venv_info.source)
    end

    log.debug("Activating venv `" .. venv_info.value .. "` from cache.")
    vim.schedule(function()
        venv.activate(venv_info.value, venv_info.type, false)
        finish(true)
    end)
end

return M
