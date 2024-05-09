local config = require("venv-selector.config")
local utils = require("venv-selector.utils")
local path = require("venv-selector.path")


local cache_file = path.expand(config.user_settings.cache.file)
local base_dir = path.get_base(cache_file)

local M = {}

function M.create_dir()
    if vim.fn.filewritable(base_dir) == 0 then
        vim.fn.mkdir(base_dir, 'p')
    end
end

function M.save(python_path, venv_type)
    M.create_dir()

    local venv_cache = {
        [vim.fn.getcwd()] = { value = python_path, type = venv_type },
    }

    local venv_cache_json = nil

    if vim.fn.filereadable(cache_file) == 1 then
        -- if cache file exists and is not empty read it and merge it with the new cache
        local cached_file = vim.fn.readfile(cache_file)
        if cached_file ~= nil and cached_file[1] ~= nil then
            local cached_json = vim.fn.json_decode(cached_file[1])
            local merged_cache = vim.tbl_deep_extend('force', cached_json, venv_cache)
            venv_cache_json = vim.fn.json_encode(merged_cache)
            dbg("Saving " .. venv_cache_json .. " to cache.")
        end
    else
        venv_cache_json = vim.fn.json_encode(venv_cache)
    end

    vim.fn.writefile({ venv_cache_json }, cache_file)
end

function M.retrieve()
    if vim.fn.filereadable(cache_file) == 1 then
        local cache_file_content = vim.fn.readfile(cache_file)

        if cache_file_content ~= nil and cache_file_content[1] ~= nil then
            local venv_cache = vim.fn.json_decode(cache_file_content[1])
            if venv_cache ~= nil and venv_cache[vim.fn.getcwd()] ~= nil then
                local venv = require("venv-selector.venv")
                venv.activate_from_cache(config.default_settings, venv_cache[vim.fn.getcwd()])
                return
            end
        end
    end
end

return M
