local config = require("venv-selector.config")
local path = require("venv-selector.path")
local log = require("venv-selector.logger")

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

function M.handle_automatic_activation()
    if config.user_settings.options.cached_venv_automatic_activation then
        M.retrieve()
    end
end

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
    log.debug("Wrote cache to " .. cache_file .. " with content: " .. venv_cache_json)
end

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

function M.retrieve()
    if config.user_settings.options.enable_cached_venvs ~= true then
        log.debug("Option 'enable_cached_venvs' is false so will not use cache.")
        return
    end

    -- Prevent multiple cache retrievals in the same session
    if cache_retrieval_done then
        log.debug("Cache retrieval already done in this session, skipping.")
        return
    end

    -- Skip cache retrieval if current file has PEP 723 metadata to avoid interfering with UV
    local current_file = vim.fn.expand("%:p")
    if current_file and current_file ~= "" and vim.bo.filetype == "python" then
        local utils = require("venv-selector.utils")
        if utils.has_pep723_metadata(current_file) then
            log.debug("Skipping cache retrieval because current file has PEP 723 metadata: " .. current_file)
            return
        end
    end
    if vim.fn.filereadable(cache_file) == 1 then
        local cache_file_content = vim.fn.readfile(cache_file)
        log.debug("Read cache from " .. cache_file)


        if cache_file_content ~= nil and cache_file_content[1] ~= nil then
            local venv_cache = vim.fn.json_decode(cache_file_content[1])
            if venv_cache ~= nil then
                -- Clean up stale entries
                local cleaned_cache = M.clean_stale_entries(venv_cache)

                -- Try to activate venv for current directory
                if cleaned_cache[vim.fn.getcwd()] ~= nil then
                    local venv = require("venv-selector.venv")
                    local venv_info = cleaned_cache[vim.fn.getcwd()]
                    if venv_info.source ~= nil then
                        venv.set_source(venv_info.source)
                    end

                    log.debug("Activating venv `" .. venv_info.value .. "` from cache.")
                    -- venv.activate(venv_info.value, venv_info.type, false)
                    vim.schedule(function()
                        venv.activate(venv_info.value, venv_info.type, false)
                    end)
                    cache_retrieval_done = true
                end
            end
        end
    end

    -- Mark as done even if no venv was activated
    cache_retrieval_done = true
end

return M
