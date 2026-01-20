-- Registry-driven config options test suite
-- Discovers options dynamically from the plugin defaults and runs registered tests.
--
-- Usage:
--   :luafile test/test_config_options.lua
--   :lua require('test.test_config_options').run_all_tests()
--
-- Register tests via:
--   register_test("option_name", fn)            -- single generic test for the option
--   register_test("option_name=true", fn)      -- test expecting option=true
--   register_test("option_name=false", fn)     -- test expecting option=false
--
-- The runner will:
-- - Iterate the options returned by `require("venv-selector.config").get_defaults().options`
-- - For each option:
--   - If tests for both "<name>=true" and "<name>=false" exist, run both.
--   - Else if a generic test registered under "<name>" exists, run it once.
--   - Else print a concise note that no test exists for that option.
--
-- The runner prints one line per test and a brief summary.
-- Set environment variable TEST_VERBOSE=1 to allow internal verbose prints during tests.

local config = require("venv-selector.config")
local search = require("venv-selector.search")
local cached_venv = require("venv-selector.cached_venv")

local M = {}
local registry = {}

-- Register a test function under a name
-- fn should return true (pass) or false, or return (true, info) or (false, message)
local function register_test(name, fn)
    if type(name) ~= "string" then error("test name must be a string") end
    if type(fn) ~= "function" then error("test fn must be a function") end
    registry[name] = fn
end

-- Expose registration for interactive / ad-hoc usage
_G.register_config_test = register_test

-- ENV: TEST_VERBOSE -> do not capture prints inside tests
local VERBOSE = false
do
    local ok, env = pcall(function() return vim.env end)
    if ok and env and env.TEST_VERBOSE == "1" then
        VERBOSE = true
    elseif os.getenv("TEST_VERBOSE") == "1" then
        VERBOSE = true
    end
end

local function wait_for(cond, timeout_ms)
    timeout_ms = timeout_ms or 8000
    local start = vim.loop.now()
    while not cond() do
        if vim.loop.now() - start > timeout_ms then
            return false
        end
        vim.wait(50)
    end
    return true
end

local function active_search_names()
    local names = {}
    for _, s in pairs(search.active_jobs or {}) do
        if s and s.name then names[#names + 1] = s.name end
    end
    return names
end

-- ============================================================================
-- Concrete tests (implemented)
-- ============================================================================

-- enable_default_searches: strict checks (we override defaults with observable cmds)
local function make_command_for_label(label)
    local sysname = vim.uv.os_uname().sysname or "Linux"
    local is_windows = sysname == "Windows_NT"
    local conf_shell = (vim.o and vim.o.shell and vim.o.shell ~= "") and vim.o.shell or nil
    local shell_is_powershell = false
    if conf_shell then
        local lc = conf_shell:lower()
        if lc:match("pwsh") or lc:match("powershell") then shell_is_powershell = true end
    end
    if is_windows then
        if shell_is_powershell then
            return (conf_shell or "powershell") .. ' -Command "Start-Sleep -Seconds 2; Write-Output ' .. label .. '"'
        else
            return 'cmd /C "ping -n 3 127.0.0.1 >nul & echo ' .. label .. '"'
        end
    else
        return "sleep 2; echo " .. label
    end
end

local function make_settings_override_defaults(enable_default_searches)
    local defaults = config.get_default_searches() or {}
    local search_table = {}
    for k, _ in pairs(defaults) do search_table[k] = { command = make_command_for_label(k) } end
    search_table.mycustom = { command = make_command_for_label("MY_CUSTOM") }

    local is_win = (vim.uv.os_uname().sysname == "Windows_NT")
    local shell_entry = {
        shell = vim.o.shell or (is_win and "cmd" or "/bin/sh"),
        shellcmdflag = vim.o.shellcmdflag or (is_win and "/C" or "-c"),
    }

    return {
        options = {
            enable_default_searches = enable_default_searches,
            shell = shell_entry,
            fd_binary_name = "fd",
            search_timeout = 5,
        },
        search = search_table,
    }
end

local function test_enable_default_searches_true()
    -- All default searches and mycustom must start (observed in active jobs)
    local defaults = config.get_default_searches() or {}
    local default_keys = {}
    local default_count = 0
    for k, _ in pairs(defaults) do default_keys[k] = true; default_count = default_count + 1 end

    config.store(make_settings_override_defaults(true))
    search.active_jobs = {}; search.active_job_count = 0; search.search_in_progress = nil
    search.run_search(nil)

    if not wait_for(function() return (search.active_job_count and search.active_job_count > 0) or (search.search_in_progress == false) end, 5000) then
        config.store(nil)
        return false, "searches did not start"
    end

    -- wait for all to appear (or completion)
    wait_for(function()
        local names = active_search_names()
        local seen = {}
        for _, n in ipairs(names) do seen[n] = true end
        local count = 0
        for k, _ in pairs(default_keys) do if seen[k] then count = count + 1 end end
        if seen.mycustom then count = count + 1 end
        return count >= (default_count + 1) or (search.search_in_progress == false)
    end, 10000)

    local names = active_search_names()
    local seen = {}
    for _, n in ipairs(names) do seen[n] = true end

    if search.search_in_progress then search.stop_search() end
    config.store(nil)

    for k, _ in pairs(default_keys) do
        if not seen[k] then return false, "missing default: " .. tostring(k) end
    end
    if not seen.mycustom then return false, "missing mycustom" end
    return true
end

local function test_enable_default_searches_false()
    local defaults = config.get_default_searches() or {}
    local default_keys = {}
    for k, _ in pairs(defaults) do default_keys[k] = true end

    config.store(make_settings_override_defaults(false))
    search.active_jobs = {}; search.active_job_count = 0; search.search_in_progress = nil
    search.run_search(nil)

    wait_for(function() return (search.active_job_count and search.active_job_count > 0) or (search.search_in_progress == false) end, 4000)
    local names = active_search_names()
    local seen = {}
    for _, n in ipairs(names) do seen[n] = true end

    wait_for(function() return search.search_in_progress == false end, 8000)
    config.store(nil)

    for k, _ in pairs(default_keys) do
        if seen[k] then return false, "default started while disabled: " .. tostring(k) end
    end
    return true
end

-- enable_cached_venvs: use writefile stubbing to detect writes
local function test_enable_cached_venvs_false()
    local orig_writefile = vim.fn.writefile
    local wrote = false
    vim.fn.writefile = function(...) wrote = true; return 0 end

    config.store({ options = { enable_cached_venvs = false } })
    pcall(function() cached_venv.save("/nonexistent/python", "venv") end)
    vim.wait(50)

    vim.fn.writefile = orig_writefile
    config.store(nil)

    if wrote then return false, "cache was written while disabled" end
    return true
end

local function test_enable_cached_venvs_true()
    local orig_writefile = vim.fn.writefile
    local wrote = false
    vim.fn.writefile = function(data, path)
        wrote = true
        return 0
    end

    config.store({ options = { enable_cached_venvs = true } })
    pcall(function() cached_venv.save("/some/fake/python", "venv") end)
    vim.wait(50)

    vim.fn.writefile = orig_writefile
    config.store(nil)

    if not wrote then return false, "cache was not written when enabled" end
    return true
end

-- Register implemented tests
register_test("enable_default_searches=true", test_enable_default_searches_true)
register_test("enable_default_searches=false", test_enable_default_searches_false)
register_test("enable_cached_venvs=true", test_enable_cached_venvs_true)
register_test("enable_cached_venvs=false", test_enable_cached_venvs_false)

-- ============================================================================
-- Skeleton registration for remaining options: simply report "no test" in runner
-- ============================================================================
local defaults = config.get_defaults() or {}
local default_options = defaults.options or {}
for opt_name, _ in pairs(default_options) do
    -- skip options we already implemented tests for
    if not registry[opt_name .. "=true"] and not registry[opt_name .. "=false"] and not registry[opt_name] then
        -- register a placeholder that returns nil (runner will treat nil as "no test")
        -- we intentionally do not mark the placeholder as passing; the runner will print "no test".
        -- To provide a real test, implement and register under:
        --   register_test("<option>"[, "=true"|"=false"], fn)
        registry[opt_name] = nil
    end
end

-- Concise runner --------------------------------------------------------------
local function run_all_tests()
    local real_print = print
    local passed, failed = 0, 0

    -- Iterate discovered options (deterministic: sorted keys)
    local option_names = {}
    for k, _ in pairs(default_options) do option_names[#option_names + 1] = k end
    table.sort(option_names)

    local idx = 0
    for _, opt in ipairs(option_names) do
        -- If both explicit true/false tests registered, run both
        local t_true = registry[opt .. "=true"]
        local t_false = registry[opt .. "=false"]
        local t_generic = registry[opt]

        if t_true or t_false then
            if t_true then
                idx = idx + 1
                local buf = {}
                local function capture_print(...) if not VERBOSE then local parts = {}; for i = 1, select('#', ...) do parts[#parts+1] = tostring(select(i, ...)) end buf[#buf+1] = table.concat(parts, " ") end end
                local old_print = print
                if not VERBOSE then print = capture_print end
                local ok, res = pcall(t_true)
                print = old_print
                if ok and (res == nil or res == true) then
                    real_print(("✓ %d) %s = true"):format(idx, opt))
                    passed = passed + 1
                else
                    failed = failed + 1
                    real_print(("✗ %d) %s = true: %s%s"):format(idx, opt, tostring(res or "<error>"), (buf[1] and (" | " .. buf[1]) or "")))
                end
            end

            if t_false then
                idx = idx + 1
                local buf = {}
                local function capture_print(...) if not VERBOSE then local parts = {}; for i = 1, select('#', ...) do parts[#parts+1] = tostring(select(i, ...)) end buf[#buf+1] = table.concat(parts, " ") end end
                local old_print = print
                if not VERBOSE then print = capture_print end
                local ok, res = pcall(t_false)
                print = old_print
                if ok and (res == nil or res == true) then
                    real_print(("✓ %d) %s = false"):format(idx, opt))
                    passed = passed + 1
                else
                    failed = failed + 1
                    real_print(("✗ %d) %s = false: %s%s"):format(idx, opt, tostring(res or "<error>"), (buf[1] and (" | " .. buf[1]) or "")))
                end
            end
        elseif type(t_generic) == "function" then
            idx = idx + 1
            local buf = {}
            local function capture_print(...) if not VERBOSE then local parts = {}; for i = 1, select('#', ...) do parts[#parts+1] = tostring(select(i, ...)) end buf[#buf+1] = table.concat(parts, " ") end end
            local old_print = print
            if not VERBOSE then print = capture_print end
            local ok, res = pcall(t_generic)
            print = old_print
            if ok and (res == nil or res == true) then
                real_print(("✓ %d) %s"):format(idx, opt))
                passed = passed + 1
            else
                failed = failed + 1
                real_print(("✗ %d) %s: %s%s"):format(idx, opt, tostring(res or "<error>"), (buf[1] and (" | " .. buf[1]) or "")))
            end
        else
            -- No test registered for this option
            idx = idx + 1
            real_print(("⚪ %d) %s: no test registered"):format(idx, opt))
        end
    end

    real_print(("Results: %d passed, %d failed"):format(passed, failed))
    return failed == 0
end

-- Exports
M.register = register_test
M.run_all_tests = run_all_tests
M.list_tests = function()
    local out = {}
    for k, _ in pairs(registry) do out[#out+1] = k end
    table.sort(out)
    return out
end

_G.run_config_tests = run_all_tests
_G.register_config_test = register_test
_G.list_config_tests = M.list_tests

return M