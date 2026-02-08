-- lua/venv-selector/uv2.lua
--
-- UV (PEP 723 "script metadata") integration for venv-selector.nvim.
--
-- Responsibilities:
-- - Detect whether a python buffer contains PEP 723 script metadata:
--     # /// script
--     ...
--     # ///
-- - If so, run:
--     uv sync --script <file>
--     uv python find --script <file>
-- - Activate the returned interpreter for that buffer as env_type="uv".
--
-- Design notes:
-- - Detection is cached per-buffer per changedtick (cheap BufEnter checks).
-- - All uv work is debounced to avoid repeated runs during typing / rapid events.
-- - The uv flow runs asynchronously using vim.system + coroutines.
-- - Only one uv flow runs at a time per buffer; changes during a run set a pending flag
--   that triggers a single re-run when the current run finishes.

local M = {}

require("venv-selector.types")
local uv = vim.uv
local log = require("venv-selector.logger")
local path_mod = require("venv-selector.path")


---True if `uv` is available on PATH.
---@type boolean
local has_uv = vim.fn.executable("uv") == 1

---Timer registry for debouncing.
---Keyed by "bufnr:tag" -> uv_timer.
---@type table<string, venv-selector.UvTimer|nil>
local timers = {}

---Debounce helper: run `fn` once after `ms` for a (bufnr, tag) key.
---If a timer already exists for that key, it is cancelled and replaced.
---
---@param bufnr integer
---@param tag string
---@param ms integer
---@param fn fun()
local function debounce(bufnr, tag, ms, fn)
    local key = ("%d:%s"):format(bufnr, tag)
    local t = timers[key]
    if t then
        t:stop()
        t:close()
        timers[key] = nil
    end
    local nt = uv.new_timer()
    if not nt then
        return
    end

    ---@cast nt venv-selector.UvTimer
    timers[key] = nt


    nt:start(ms, 0, vim.schedule_wrap(function()
        timers[key] = nil
        fn()
    end))
end

---Check whether `bufnr` is a normal python file buffer.
---
---@param bufnr integer
---@return boolean ok
local function valid_py_buf(bufnr)
    return vim.api.nvim_buf_is_valid(bufnr)
        and vim.bo[bufnr].buftype == ""
        and vim.bo[bufnr].filetype == "python"
end

---Detect whether a buffer is a UV PEP 723 script buffer, with per-changedtick caching.
---
---Caching:
--- - Stores the computed boolean in:
---     vim.b[bufnr].venv_selector_uv_detect_val
--- - Stores the tick used for that cached value in:
---     vim.b[bufnr].venv_selector_uv_detect_tick
---
---Detection logic:
--- - Scan the first ~200 lines looking for:
---     "# /// script" (start)
---     "# ///"        (end)
--- - Returns true if both markers are found in order.
---
---@param bufnr integer
---@return boolean is_uv
local function is_uv_buffer_cached(bufnr)
    if not valid_py_buf(bufnr) then
        return false
    end

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

---Public: return whether the buffer appears to be a UV PEP 723 script.
---
---@param bufnr integer
---@return boolean is_uv
function M.is_uv_buffer(bufnr)
    return is_uv_buffer_cached(bufnr)
end

---Log multi-line output by splitting on newline boundaries.
---
---@param prefix string
---@param text string|nil
local function log_multiline(prefix, text)
    if not text or text == "" then
        return
    end
    for line in text:gmatch("[^\r\n]+") do
        log.debug(prefix .. line)
    end
end

---Debounce wrapper specialized for uv flows:
--- - Validates python buffer
--- - Validates it still matches uv metadata
--- - Re-checks both conditions after the delay before calling fn
---
---@param bufnr integer|nil
---@param tag string
---@param ms integer
---@param fn fun(bufnr: integer)
local function debounce_uv(bufnr, tag, ms, fn)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if not valid_py_buf(bufnr) then return end
    if not is_uv_buffer_cached(bufnr) then return end

    debounce(bufnr, tag, ms, function()
        if not valid_py_buf(bufnr) then return end
        if not is_uv_buffer_cached(bufnr) then return end
        fn(bufnr)
    end)
end

---Return the preferred output string from a vim.system result.
---Prefers stderr if non-empty; otherwise stdout.
---
---@param res venv-selector.SystemResult
---@return string|nil out
local function uv_out(res)
    return (res.stderr and res.stderr ~= "") and res.stderr or res.stdout
end

---Extract the first non-empty line from a string.
---
---@param text string|nil
---@return string|nil line
local function first_line(text)
    if not text or text == "" then return nil end
    for line in text:gmatch("[^\r\n]+") do
        if line and line ~= "" then
            return line
        end
    end
    return nil
end

---Coroutine-friendly "await" wrapper for vim.system.
---Must be called inside a coroutine created via coroutine.create().
---
---@param cmd string[] Command argv
---@param opts table Options passed to vim.system (e.g. {text=true, cwd=...})
---@return venv-selector.SystemResult res vim.system result
local function await_system(cmd, opts)
    local co = coroutine.running()
    if not co then
        error("await_system must be called inside a coroutine")
    end

    vim.system(cmd, opts, function(res)
        vim.schedule(function()
            local ok, err = coroutine.resume(co, res)
            if not ok then
                log.debug("uv2: coroutine resume failed: " .. tostring(err))
            end
        end)
    end)

    return coroutine.yield()
end

---Activate a uv python interpreter for a buffer (no cache save).
---No-op if the requested python is already globally active.
---
---@param bufnr integer
---@param python_path string
local function apply_uv_python(bufnr, python_path)
    if not python_path or python_path == "" then
        return
    end
    if path_mod.current_python_path == python_path then
        return
    end
    require("venv-selector.venv").activate_for_buffer(python_path, "uv", bufnr, { save_cache = false })
end

---Run `uv sync --script <file>` for a script buffer.
---Logs output and returns true if the command succeeded.
---
---@param bufnr integer
---@param file string Absolute file path
---@return boolean ok
local function uv_sync(bufnr, file)
    if not has_uv then
        log.debug("uv not found.")
        return false
    end
    if not file or file == "" then
        return false
    end

    local cmd = { "uv", "sync", "--script", file }
    log.debug("Running uv command: " .. table.concat(cmd, " "))

    local res = await_system(cmd, { text = true, cwd = vim.fn.fnamemodify(file, ":h") })
    local out = uv_out(res)
    log_multiline("uv sync: ", out)

    if res.code ~= 0 then
        vim.notify(out or "uv sync failed", vim.log.levels.ERROR, { title = "VenvSelector" })
        return false
    end
    return true
end

---Run `uv python find --script <file>` and return the interpreter path.
---
---@param bufnr integer
---@param file string Absolute file path
---@return string|nil python_path
local function uv_python_find(bufnr, file)
    if not has_uv then
        log.debug("uv not found.")
        return nil
    end
    if not file or file == "" then
        return nil
    end

    local cmd = { "uv", "python", "find", "--script", file }
    log.debug("Running uv command: " .. table.concat(cmd, " "))

    local res = await_system(cmd, { text = true, cwd = vim.fn.fnamemodify(file, ":h") })
    if res.code ~= 0 then
        return nil
    end

    local python_path = first_line(uv_out(res))
    return python_path
end

---Mark the current uv run as finished for a buffer.
---If the buffer was marked "pending" while running (metadata changed),
---trigger a single additional run.
---
---@param bufnr integer
local function finish_uv_run(bufnr)
    vim.b[bufnr].venv_selector_uv_running = false

    -- If metadata changed while running, rerun once.
    if vim.b[bufnr].venv_selector_uv_pending then
        vim.b[bufnr].venv_selector_uv_pending = false
        M.run_uv_flow_if_needed(bufnr)
    end
end

---Start the async uv flow in a coroutine:
--- - uv sync
--- - uv python find
--- - cache last python and last tick on the buffer
--- - activate interpreter for the buffer
---
---@param bufnr integer
local function start_uv_flow_async(bufnr)
    local co = coroutine.create(function()
        local ok, err = xpcall(function()
            local file = vim.api.nvim_buf_get_name(bufnr)
            if file == "" then
                return
            end

            if not uv_sync(bufnr, file) then
                return
            end

            local python_path = uv_python_find(bufnr, file)
            if python_path and python_path ~= "" then
                vim.b[bufnr].venv_selector_uv_last_tick = vim.b[bufnr].changedtick or 0
                vim.b[bufnr].venv_selector_uv_last_python = python_path
                apply_uv_python(bufnr, python_path)
            end
        end, debug.traceback)

        finish_uv_run(bufnr)

        if not ok then
            log.debug("uv2: uv flow error: " .. tostring(err))
        end
    end)

    local ok, err = coroutine.resume(co)
    if not ok then
        finish_uv_run(bufnr)
        log.debug("uv2: coroutine start failed: " .. tostring(err))
    end
end

---Run uv flow if needed for a buffer.
---Debounced and guarded by:
--- - per-buffer changedtick: avoids rerunning if nothing changed
--- - running flag: avoids overlapping uv runs; sets pending flag instead
---
---@param bufnr integer|nil
function M.run_uv_flow_if_needed(bufnr)
    debounce_uv(bufnr, "uvflow", 120, function(b)
        local tick = vim.b[b].changedtick or 0
        if vim.b[b].venv_selector_uv_last_tick == tick then
            return
        end

        if vim.b[b].venv_selector_uv_running then
            vim.b[b].venv_selector_uv_pending = true
            return
        end

        vim.b[b].venv_selector_uv_running = true
        log.debug("run_uv_flow_if_needed")
        start_uv_flow_async(b)
    end)
end

---Ensure a uv buffer has the correct interpreter activated.
---If we have a cached last_python for the buffer, apply it immediately.
---Otherwise, run the uv flow to compute it.
---
---@param bufnr integer|nil
function M.ensure_uv_buffer_activated(bufnr)
    debounce_uv(bufnr, "uviens", 80, function(b)
        log.debug("ensure_uv_buffer_activated")

        local last_python = vim.b[b].venv_selector_uv_last_python
        if last_python and last_python ~= "" then
            apply_uv_python(b, last_python)
            return
        end

        M.run_uv_flow_if_needed(b)
    end)
end

---@cast M venv-selector.Uv2Module
return M
