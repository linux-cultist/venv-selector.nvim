local M = {}

local uv = vim.uv or vim.loop
local log = require("venv-selector.logger")
local path_mod = require("venv-selector.path")

local has_uv = vim.fn.executable("uv") == 1

-- (bufnr, tag) -> timer
local timers = {}

local function debounce(bufnr, tag, ms, fn)
    local key = ("%d:%s"):format(bufnr, tag)
    local t = timers[key]
    if t then
        t:stop(); t:close()
        timers[key] = nil
    end
    t = uv.new_timer()
    timers[key] = t
    t:start(ms, 0, vim.schedule_wrap(function()
        timers[key] = nil
        fn()
    end))
end

local function valid_py_buf(bufnr)
    return vim.api.nvim_buf_is_valid(bufnr)
        and vim.bo[bufnr].buftype == ""
        and vim.bo[bufnr].filetype == "python"
end

-- cache uv detection per changedtick
local function is_uv_buffer_cached(bufnr)
    if not valid_py_buf(bufnr) then return false end
    local tick = vim.b[bufnr].changedtick or 0
    local cache_tick = vim.b[bufnr].venv_selector_uv_detect_tick
    if cache_tick == tick and vim.b[bufnr].venv_selector_uv_detect_val ~= nil then
        return vim.b[bufnr].venv_selector_uv_detect_val
    end

    local ok = false
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 200, false)
    local seen_start = false
    for _, line in ipairs(lines) do
        if not seen_start then
            if line:match("^%s*#%s*///%s*script%s*$") then
                seen_start = true
            end
        else
            if line:match("^%s*#%s*///%s*$") then
                ok = true
                break
            end
        end
    end

    vim.b[bufnr].venv_selector_uv_detect_tick = tick
    vim.b[bufnr].venv_selector_uv_detect_val = ok
    return ok
end

function M.is_uv_buffer(bufnr)
    return is_uv_buffer_cached(bufnr)
end

local function log_multiline(prefix, text)
    if not text or text == "" then return end
    for line in text:gmatch("[^\r\n]+") do
        log.debug(prefix .. line)
    end
end

local function run_uv_sync_for_buffer(bufnr, done)
    if not has_uv then
        log.debug("uv not found.")
        return done(false)
    end
    local file = vim.api.nvim_buf_get_name(bufnr)
    if file == "" then return done(false) end

    local cmd = { "uv", "sync", "--script", file }
    log.debug("Running uv command: " .. table.concat(cmd, " "))
    vim.system(cmd, { text = true, cwd = vim.fn.fnamemodify(file, ":h") }, function(res)
        vim.schedule(function()
            local out = (res.stderr and res.stderr ~= "") and res.stderr or res.stdout
            log_multiline("uv sync: ", out)
            if res.code ~= 0 then
                vim.notify(out or "uv sync failed", vim.log.levels.ERROR, { title = "VenvSelector" })
                return done(false)
            end
            done(true)
        end)
    end)
end

local function run_uv_python_find(bufnr, done)
    if not has_uv then
        log.debug("uv not found.")
        return done(false)
    end
    local file = vim.api.nvim_buf_get_name(bufnr)
    if file == "" then return done(false) end

    local cmd = { "uv", "python", "find", "--script", file }
    log.debug("Running uv command: " .. table.concat(cmd, " "))
    vim.system(cmd, { text = true, cwd = vim.fn.fnamemodify(file, ":h") }, function(res)
        vim.schedule(function()
            local out = (res.stderr and res.stderr ~= "") and res.stderr or res.stdout
            if res.code ~= 0 or not out or out == "" then
                return done(false)
            end
            local python_path
            for line in out:gmatch("[^\r\n]+") do
                if line and line ~= "" then
                    python_path = line; break
                end
            end
            if not python_path or python_path == "" then
                return done(false)
            end
            done(true, python_path)
        end)
    end)
end

local function apply_uv_python(bufnr, python_path)
    if not python_path or python_path == "" then return end
    if path_mod.current_python_path == python_path then return end
    require("venv-selector.venv").activate_for_buffer(python_path, "uv", bufnr, { save_cache = false })
end

local function run_uv_flow(bufnr)
    run_uv_sync_for_buffer(bufnr, function(sync_ok)
        if not sync_ok then
            vim.b[bufnr].venv_selector_uv_running = false
            return
        end
        run_uv_python_find(bufnr, function(ok, python_path)
            vim.b[bufnr].venv_selector_uv_running = false

            if ok and python_path and python_path ~= "" then
                vim.b[bufnr].venv_selector_uv_last_tick = vim.b[bufnr].changedtick or 0
                vim.b[bufnr].venv_selector_uv_last_python = python_path
                apply_uv_python(bufnr, python_path)
            end

            -- if metadata changed while running, rerun once
            if vim.b[bufnr].venv_selector_uv_pending then
                vim.b[bufnr].venv_selector_uv_pending = false
                M.run_uv_flow_if_needed(bufnr)
            end
        end)
    end)
end

function M.run_uv_flow_if_needed(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not valid_py_buf(bufnr) then return end
    if not is_uv_buffer_cached(bufnr) then return end

    debounce(bufnr, "uvflow", 120, function()
        if not valid_py_buf(bufnr) then return end
        if not is_uv_buffer_cached(bufnr) then return end

        local tick = vim.b[bufnr].changedtick or 0
        if vim.b[bufnr].venv_selector_uv_last_tick == tick then
            return
        end

        if vim.b[bufnr].venv_selector_uv_running then
            vim.b[bufnr].venv_selector_uv_pending = true
            return
        end

        vim.b[bufnr].venv_selector_uv_running = true
        log.debug("run_uv_flow_if_needed")
        run_uv_flow(bufnr)
    end)
end

function M.ensure_uv_buffer_activated(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not valid_py_buf(bufnr) then return end
    if not is_uv_buffer_cached(bufnr) then return end

    debounce(bufnr, "uviens", 80, function()
        if not valid_py_buf(bufnr) then return end
        if not is_uv_buffer_cached(bufnr) then return end

        log.debug("ensure_uv_buffer_activated")

        local last_python = vim.b[bufnr].venv_selector_uv_last_python
        if last_python and last_python ~= "" then
            apply_uv_python(bufnr, last_python)
            return
        end

        M.run_uv_flow_if_needed(bufnr)
    end)
end

return M
