local config = require 'venv-selector.config'
local path = require 'venv-selector.path'
local log = require 'venv-selector.logger'
local utils = require 'venv-selector.utils'

local cache_file, base_dir, lsp_file_name

local M = {}

function M.create_dir()
    if vim.fn.filewritable(base_dir) == 0 then
        vim.fn.mkdir(base_dir, 'p')
    end
end

function M.save(python_path, venv_type, venv_source)
    if config.default_settings.options.enable_cached_venvs ~= true then
        log.debug "Option 'enable_cached_venvs' is false so will not use cache."
        return
    end

    M.create_dir()

    local venv_cache = {
        value = python_path,
        type = venv_type,
        source = venv_source,
    }

    if lsp_file_name ~= nil then
        venv_cache = {
            [lsp_file_name] = { value = python_path, type = venv_type, source = venv_source },
        }
    end

    local venv_cache_json = nil

    if vim.fn.filereadable(cache_file) == 1 then
        -- if cache file exists and is not empty read it and merge it with the new cache
        local cached_file = vim.fn.readfile(cache_file)
        if cached_file ~= nil and cached_file[1] ~= nil then
            local cached_json = vim.fn.json_decode(cached_file[1])
            local merged_cache = vim.tbl_deep_extend('force', cached_json, venv_cache)
            venv_cache_json = vim.fn.json_encode(merged_cache)
            log.debug('Cache content: ', venv_cache_json)
        end
    else
        venv_cache_json = vim.fn.json_encode(venv_cache)
        log.debug('Cache content: ', venv_cache_json)
    end

    vim.fn.writefile({ venv_cache_json }, cache_file)
    log.debug('Wrote cache content to ' .. cache_file)
end

function M.retrieve(client, bufnr)
    if config.default_settings.options.enable_cached_venvs ~= true then
        log.debug "Option 'enable_cached_venvs' is false so will not use cache."
        return
    end

    local project_root_dir = vim.fn.getcwd()
    if client then
        project_root_dir = client.config.root_dir
    end

    -- nvim opens the project
    if path.is_directory(project_root_dir) == true then
        cache_file = path.expand(project_root_dir .. '/.venv_cache.json')
    else
        cache_file = path.expand '/tmp/venv_cache.json'
        lsp_file_name = vim.api.nvim_buf_get_name(0)
    end
    cache_filebase_dir = path.get_base(cache_file)

    if vim.fn.filereadable(cache_file) == 1 then
        local cache_file_content = vim.fn.readfile(cache_file)
        log.debug('Read cache from ' .. cache_file)
        log.debug('Cache content: ', cache_file_content)

        if cache_file_content ~= nil then
            local venv_cache = vim.fn.json_decode(cache_file_content[1])
            local venv = require 'venv-selector.venv'

            if lsp_file_name ~= nil then
                if venv_cache ~= nil and venv_cache[lsp_file_name] ~= nil then
                    venv.activate_from_cache(config.default_settings, venv_cache[lsp_file_name])
                    return
                end
            else
                venv.activate_from_cache(config.default_settings, venv_cache)
                return
            end
        end
    end
end

return M
