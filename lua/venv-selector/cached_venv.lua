local config = require("venv-selector.config")
local log = require("venv-selector.logger")
local workspace = require("venv-selector.workspace")

local M = {}

function M.chache_file()
    local cache_file
    if workspace.list_folders() == nil or #workspace.list_folders() == 0 then
        cache_file = "/tmp/.venv_cache.json"
    else
        cache_file = workspace.list_folders()[1] .. "/.venv_cache.json"
    end
    return cache_file
end

function M.save(python_path, venv_type)
    if config.user_settings.options.enable_cached_venvs ~= true then
        log.debug("Option 'enable_cached_venvs' is false so will not use cache.")
        return
    end

    local cache_file = M.chache_file()

    local venv_cache = {
        value = python_path,
        type = venv_type,
    }

    if workspace.list_folders() == nil or #workspace.list_folders() == 0 then
        venv_cache = { [vim.fn.getcwd()] = venv_cache }
    end

    local venv_cache_json = nil

    if vim.fn.filereadable(cache_file) == 1 then
        -- if cache file exists and is not empty read it and merge it with the new cache
        local cached_file = vim.fn.readfile(cache_file)
        if cached_file ~= nil and cached_file[1] ~= nil then
            local cached_json = vim.fn.json_decode(cached_file[1])
            local merged_cache = vim.tbl_deep_extend("force", cached_json, venv_cache)
            venv_cache_json = vim.fn.json_encode(merged_cache)
            log.debug("Cache content: ", venv_cache_json)
        else
            venv_cache_json = vim.fn.json_encode(venv_cache)
        end
    else
        venv_cache_json = vim.fn.json_encode(venv_cache)
        log.debug("Cache content: ", venv_cache_json)
    end

    vim.fn.writefile({ venv_cache_json }, cache_file)
    log.debug("Wrote cache content to " .. cache_file)
end

function M.retrieve()
    if config.user_settings.options.enable_cached_venvs ~= true then
        log.debug("Option 'enable_cached_venvs' is false so will not use cache.")
        return
    end

    log.debug("workspace: " .. vim.inspect(workspace.list_folders()))

    local cache_file = M.chache_file()

    if vim.fn.filereadable(cache_file) == 1 then
        local cache_file_content = vim.fn.readfile(cache_file)
        log.debug("Read cache from " .. cache_file)
        log.debug("Cache content: ", cache_file_content)

        if cache_file_content ~= nil and cache_file_content[1] ~= nil then
            local venv_cache = vim.fn.json_decode(cache_file_content[1])
            local venv = require("venv-selector.venv")

            local venv_info
            if workspace.list_folders() == nil or #workspace.list_folders() == 0 then
                venv_info = venv_cache[vim.fn.getcwd()]
            else
                venv_info = venv_cache
            end

            if venv_info ~= nil then
                log.debug("Activating venv `" .. venv_info.value .. "` from cache.")
                venv.activate(venv_info.value, venv_info.type, false)
                return
            end
        end
    end
end

return M
