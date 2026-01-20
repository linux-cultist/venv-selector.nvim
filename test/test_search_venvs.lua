-- Test script for venv-selector search functionality
-- This creates temporary test directories with various venv structures
-- and verifies that the search finds python executables correctly.
--
-- Usage:
--   :luafile test/test_search_venvs.lua
--   :lua run_all_tests()

local search = require("venv-selector.search")

local M = {}

-- Test configuration
local test_config = {
    test_dir = vim.fn.tempname() .. "_venv_test",
    timeout = 10000, -- 10 seconds timeout
}

---Detect if running on Windows
---@return boolean
local function is_windows()
    return vim.uv.os_uname().sysname == "Windows_NT"
end

---Get the path separator for the current OS
---@return string
local function get_path_sep()
    return is_windows() and "\\" or "/"
end

---Join path components with OS-appropriate separator
---@param ... string
---@return string
local function path_join(...)
    local parts = {...}
    local sep = get_path_sep()
    return table.concat(parts, sep)
end

---Get the appropriate python executable name for the OS
---@return string
local function get_python_name()
    return is_windows() and "python.exe" or "python"
end

---Get the appropriate bin/Scripts directory name for the OS
---@return string
local function get_bin_dir()
    return is_windows() and "Scripts" or "bin"
end

---Create a directory and all parent directories
---@param path string
local function mkdir_p(path)
    vim.fn.mkdir(path, "p")
end

---Create a file with optional content
---@param path string
---@param content? string
local function create_file(path, content)
    local file = io.open(path, "w")
    if file then
        if content then
            file:write(content)
        end
        file:close()
    end
end

---Remove test directory and all contents
local function cleanup_test_dir()
    if vim.fn.isdirectory(test_config.test_dir) == 1 then
        vim.fn.delete(test_config.test_dir, "rf")
    end
end

---Setup test directory with various venv structures
local function setup_test_directories()
    cleanup_test_dir()
    mkdir_p(test_config.test_dir)
    
    local bin_dir = get_bin_dir()
    local python_name = get_python_name()
    local shebang = is_windows() and "" or "#!/usr/bin/env python3"
    
    -- Standard venv in project root
    local venv1 = path_join(test_config.test_dir, "project1", "venv")
    mkdir_p(path_join(venv1, bin_dir))
    create_file(path_join(venv1, bin_dir, python_name), shebang)
    create_file(path_join(venv1, "pyvenv.cfg"), "version = 3.11.0")
    
    -- .venv directory (common pattern)
    local venv2 = path_join(test_config.test_dir, "project2", ".venv")
    mkdir_p(path_join(venv2, bin_dir))
    create_file(path_join(venv2, bin_dir, python_name), shebang)
    create_file(path_join(venv2, "pyvenv.cfg"), "version = 3.10.0")
    
    -- Nested venv
    local venv3 = path_join(test_config.test_dir, "project3", "environments", "dev_env")
    mkdir_p(path_join(venv3, bin_dir))
    create_file(path_join(venv3, bin_dir, python_name), shebang)
    create_file(path_join(venv3, "pyvenv.cfg"), "version = 3.9.0")
    
    -- virtualenv (slightly different structure)
    local venv4 = path_join(test_config.test_dir, "project4", "env")
    mkdir_p(path_join(venv4, bin_dir))
    create_file(path_join(venv4, bin_dir, python_name), shebang)
    create_file(path_join(venv4, bin_dir, "activate"), "")
    
    -- Poetry-style venv
    local venv5 = path_join(test_config.test_dir, "project5", ".venv")
    mkdir_p(path_join(venv5, bin_dir))
    create_file(path_join(venv5, bin_dir, python_name), shebang)
    create_file(path_join(venv5, "pyvenv.cfg"), "")
    
    -- Multiple venvs in same project
    local venv6a = path_join(test_config.test_dir, "project6", "venv")
    mkdir_p(path_join(venv6a, bin_dir))
    create_file(path_join(venv6a, bin_dir, python_name), shebang)
    
    local venv6b = path_join(test_config.test_dir, "project6", ".venv")
    mkdir_p(path_join(venv6b, bin_dir))
    create_file(path_join(venv6b, bin_dir, python_name), shebang)
    
    -- Hidden directory with venv
    local venv7 = path_join(test_config.test_dir, ".hidden_project", "venv")
    mkdir_p(path_join(venv7, bin_dir))
    create_file(path_join(venv7, bin_dir, python_name), shebang)
    
    -- Path with spaces
    local venv8 = path_join(test_config.test_dir, "project with spaces", "venv")
    mkdir_p(path_join(venv8, bin_dir))
    create_file(path_join(venv8, bin_dir, python_name), shebang)
    create_file(path_join(venv8, "pyvenv.cfg"), "version = 3.11.0")
    
    -- Poetry-style (Cache/virtualenvs)
    local venv9 = path_join(test_config.test_dir, "poetry_cache", "myproject-py3.11")
    mkdir_p(path_join(venv9, bin_dir))
    create_file(path_join(venv9, bin_dir, python_name), shebang)
    
    -- Pyenv-style (versions)
    local venv10 = path_join(test_config.test_dir, "pyenv_versions", "3.11.0")
    mkdir_p(path_join(venv10, bin_dir))
    create_file(path_join(venv10, bin_dir, python_name), shebang)
    
    -- Pipenv-style (virtualenvs with hash)
    local venv11 = path_join(test_config.test_dir, "pipenv_venvs", "myproject-abc123")
    mkdir_p(path_join(venv11, bin_dir))
    create_file(path_join(venv11, bin_dir, python_name), shebang)
    
    -- Hatch-style
    local venv12 = path_join(test_config.test_dir, "hatch_envs", "default")
    mkdir_p(path_join(venv12, bin_dir))
    create_file(path_join(venv12, bin_dir, python_name), shebang)
    
    -- Anaconda/conda style
    local venv13 = path_join(test_config.test_dir, "conda_envs", "myenv")
    mkdir_p(path_join(venv13, bin_dir))
    create_file(path_join(venv13, bin_dir, python_name), shebang)
    
    print("✓ Created test directory structure at: " .. test_config.test_dir)
    print("  OS: " .. (is_windows() and "Windows" or "Unix"))
    print("  Python executable: " .. python_name)
    print("  Bin directory: " .. bin_dir)
    return test_config.test_dir
end

---Wait for condition with timeout
---@param condition fun(): boolean
---@param timeout_ms? integer
---@return boolean success
local function wait_for(condition, timeout_ms)
    timeout_ms = timeout_ms or test_config.timeout
    local start = vim.loop.now()
    while not condition() do
        if vim.loop.now() - start > timeout_ms then
            return false
        end
        vim.wait(100)
    end
    return true
end

---Test 1: Search finds python executables
function M.test_find_python_executables()
    print("\n=== Test 1: Find python executables ===")
    
    local test_dir = setup_test_directories()
    local results = {}
    local done = false
    
    -- Create custom search command for test directory
    -- Normalize path for fd (it expects forward slashes even on Windows)
    local normalized_path = test_dir:gsub("\\", "/")
    local python_pattern = get_python_name() .. "$"
    local search_cmd = string.format("fd -H -a -t f -E .git '%s' %s", python_pattern, normalized_path)
    
    print("  Search command: " .. search_cmd)
    
    search.run_search({
        on_result = function(result)
            table.insert(results, result)
            print(string.format("  Found: %s", result.name))
        end,
        on_complete = function()
            done = true
        end
    }, { args = search_cmd })
    
    -- Wait for search to complete
    local success = wait_for(function() return done end)
    
    if not success then
        print("✗ Test FAILED: Search timeout")
        cleanup_test_dir()
        return false
    end
    
    -- Verify results
    local expected_count = 13 -- We created 13 venvs with python executables
    if #results < expected_count then
        print(string.format("✗ Test FAILED: Expected at least %d results, got %d", expected_count, #results))
        cleanup_test_dir()
        return false
    end
    
    print(string.format("✓ Test PASSED: Found %d python executables", #results))
    cleanup_test_dir()
    return true
end

---Test 2: Verify result structure
function M.test_result_structure()
    print("\n=== Test 2: Verify result structure ===")
    
    local test_dir = setup_test_directories()
    local results = {}
    local done = false
    local errors = {}
    
    local normalized_path = test_dir:gsub("\\", "/")
    local python_pattern = get_python_name() .. "$"
    local search_cmd = string.format("fd -H -a -t f '%s' %s", python_pattern, normalized_path)
    
    search.run_search({
        on_result = function(result)
            table.insert(results, result)
            
            -- Validate structure
            if not result.path then
                table.insert(errors, "Result missing 'path' field")
            end
            if not result.name then
                table.insert(errors, "Result missing 'name' field")
            end
            if not result.type then
                table.insert(errors, "Result missing 'type' field")
            end
            if not result.source then
                table.insert(errors, "Result missing 'source' field")
            end
            if not result.icon then
                table.insert(errors, "Result missing 'icon' field")
            end
            
            -- Verify the path contains python executable
            if not result.path:match(get_python_name()) then
                table.insert(errors, "Result path doesn't contain python executable: " .. result.path)
            end
        end,
        on_complete = function()
            done = true
        end
    }, { args = search_cmd })
    
    wait_for(function() return done end)
    
    if #errors > 0 then
        print("✗ Test FAILED: Result structure validation errors:")
        for _, err in ipairs(errors) do
            print("  - " .. err)
        end
        cleanup_test_dir()
        return false
    end
    
    if #results == 0 then
        print("✗ Test FAILED: No results found")
        cleanup_test_dir()
        return false
    end
    
    print(string.format("✓ Test PASSED: All %d results have correct structure", #results))
    cleanup_test_dir()
    return true
end

---Test 3: Search can be stopped
function M.test_search_can_be_stopped()
    print("\n=== Test 3: Search can be stopped ===")
    
    local test_dir = setup_test_directories()
    local result_count = 0
    local done = false
    
    -- Create a search that will take some time
    local normalized_path = test_dir:gsub("\\", "/")
    local search_cmd = string.format("fd -H -a -t f '.*' %s", normalized_path)
    
    search.run_search({
        on_result = function(result)
            result_count = result_count + 1
        end,
        on_complete = function()
            done = true
        end
    }, { args = search_cmd })
    
    -- Wait for search to actually start
    local started = wait_for(function() return search.search_in_progress end, 2000)
    
    if not started then
        print("✗ Test FAILED: Search didn't start in time")
        cleanup_test_dir()
        return false
    end
    
    -- Now stop the search
    search.stop_search()
    
    -- Verify search was stopped
    local stopped = not search.search_in_progress
    
    if not stopped then
        print("✗ Test FAILED: Search still in progress after stop")
        cleanup_test_dir()
        return false
    end
    
    print("✓ Test PASSED: Search stopped successfully")
    cleanup_test_dir()
    return true
end

---Test 4: Interactive search with specific path
function M.test_interactive_search()
    print("\n=== Test 4: Interactive search with specific path ===")
    
    local test_dir = setup_test_directories()
    local results = {}
    local done = false
    
    -- Search only in project1
    local normalized_path = test_dir:gsub("\\", "/")
    local python_pattern = get_python_name() .. "$"
    local search_cmd = string.format("fd -H -a -t f '%s' %s/project1", python_pattern, normalized_path)
    
    search.run_search({
        on_result = function(result)
            table.insert(results, result)
        end,
        on_complete = function()
            done = true
        end
    }, { args = search_cmd })
    
    wait_for(function() return done end)
    
    -- Should only find python in project1
    if #results ~= 1 then
        print(string.format("✗ Test FAILED: Expected 1 result in project1, got %d", #results))
        cleanup_test_dir()
        return false
    end
    
    -- Verify the path contains project1
    if not results[1].path:match("project1") then
        print("✗ Test FAILED: Result doesn't contain 'project1' in path: " .. results[1].path)
        cleanup_test_dir()
        return false
    end
    
    print("✓ Test PASSED: Interactive search found correct result")
    cleanup_test_dir()
    return true
end

---Test 5: Search finds hidden directories
function M.test_find_hidden_directories()
    print("\n=== Test 5: Search finds hidden directories ===")
    
    local test_dir = setup_test_directories()
    local results = {}
    local done = false
    
    -- Search including hidden directories
    local normalized_path = test_dir:gsub("\\", "/")
    local python_pattern = get_python_name() .. "$"
    local search_cmd = string.format("fd -H -a -t f '%s' %s/.hidden_project", python_pattern, normalized_path)
    
    search.run_search({
        on_result = function(result)
            table.insert(results, result)
        end,
        on_complete = function()
            done = true
        end
    }, { args = search_cmd })
    
    wait_for(function() return done end)
    
    if #results == 0 then
        print("✗ Test FAILED: Hidden directory python not found")
        cleanup_test_dir()
        return false
    end
    
    -- Verify path contains hidden directory
    if not results[1].path:match(".hidden_project") then
        print("✗ Test FAILED: Result doesn't contain '.hidden_project' in path: " .. results[1].path)
        cleanup_test_dir()
        return false
    end
    
    print("✓ Test PASSED: Hidden directory python found")
    cleanup_test_dir()
    return true
end

---Test 6: Multiple searches can be run sequentially
function M.test_sequential_searches()
    print("\n=== Test 6: Sequential searches ===")
    
    local test_dir = setup_test_directories()
    
    local normalized_path = test_dir:gsub("\\", "/")
    local python_pattern = get_python_name() .. "$"
    
    -- First search
    local results1 = {}
    local done1 = false
    local search_cmd1 = string.format("fd -H -a -t f '%s' %s/project1", python_pattern, normalized_path)
    
    search.run_search({
        on_result = function(result)
            table.insert(results1, result)
        end,
        on_complete = function()
            done1 = true
        end
    }, { args = search_cmd1 })
    
    wait_for(function() return done1 end)
    
    -- Second search
    local results2 = {}
    local done2 = false
    local search_cmd2 = string.format("fd -H -a -t f '%s' %s/project2", python_pattern, normalized_path)
    
    search.run_search({
        on_result = function(result)
            table.insert(results2, result)
        end,
        on_complete = function()
            done2 = true
        end
    }, { args = search_cmd2 })
    
    wait_for(function() return done2 end)
    
    if #results1 == 0 or #results2 == 0 then
        print("✗ Test FAILED: One or both searches returned no results")
        cleanup_test_dir()
        return false
    end
    
    print(string.format("✓ Test PASSED: Sequential searches completed (search1: %d, search2: %d)", 
        #results1, #results2))
    cleanup_test_dir()
    return true
end

---Test 7: Search handles paths with spaces
function M.test_path_with_spaces()
    print("\n=== Test 7: Search handles paths with spaces ===")
    
    local test_dir = setup_test_directories()
    local results = {}
    local done = false
    
    -- Search in directory with spaces in name
    local normalized_path = test_dir:gsub("\\", "/")
    local python_pattern = get_python_name() .. "$"
    local search_cmd = string.format("fd -H -a -t f '%s' '%s/project with spaces'", python_pattern, normalized_path)
    
    print("  Search command: " .. search_cmd)
    
    search.run_search({
        on_result = function(result)
            table.insert(results, result)
            print(string.format("  Found: %s", result.name))
        end,
        on_complete = function()
            done = true
        end
    }, { args = search_cmd })
    
    wait_for(function() return done end)
    
    if #results == 0 then
        print("✗ Test FAILED: Path with spaces not found")
        cleanup_test_dir()
        return false
    end
    
    -- Verify the path contains "project with spaces"
    local found_space_path = false
    for _, result in ipairs(results) do
        if result.path:match("project with spaces") or result.path:match("project%%20with%%20spaces") then
            found_space_path = true
            break
        end
    end
    
    if not found_space_path then
        print("✗ Test FAILED: Result doesn't contain 'project with spaces' in path")
        for _, result in ipairs(results) do
            print("  Path: " .. result.path)
        end
        cleanup_test_dir()
        return false
    end
    
    print("✓ Test PASSED: Path with spaces handled correctly")
    cleanup_test_dir()
    return true
end

---Test 8: Variable substitution $CWD works
function M.test_variable_substitution_cwd()
    print("\n=== Test 8: Variable substitution $CWD ===")
    
    local test_dir = setup_test_directories()
    local results = {}
    local done = false
    
    -- Change to test directory
    local original_cwd = vim.fn.getcwd()
    vim.cmd("cd " .. vim.fn.fnameescape(test_dir))
    
    -- Use $CWD variable which should be substituted
    local python_pattern = get_python_name() .. "$"
    local search_cmd = string.format("fd -H -a -t f '%s' $CWD/project1", python_pattern)
    
    print("  Search command: " .. search_cmd)
    
    search.run_search({
        on_result = function(result)
            table.insert(results, result)
        end,
        on_complete = function()
            done = true
        end
    }, { args = search_cmd })
    
    wait_for(function() return done end)
    
    -- Restore original directory
    vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
    
    if #results ~= 1 then
        print(string.format("✗ Test FAILED: Expected 1 result with $CWD substitution, got %d", #results))
        cleanup_test_dir()
        return false
    end
    
    print("✓ Test PASSED: $CWD variable substitution works")
    cleanup_test_dir()
    return true
end

---Test 9: Search finds different venv types
function M.test_different_venv_types()
    print("\n=== Test 9: Search finds different venv types ===")
    
    local test_dir = setup_test_directories()
    local results = {}
    local done = false
    
    local normalized_path = test_dir:gsub("\\", "/")
    local python_pattern = get_python_name() .. "$"
    local search_cmd = string.format("fd -H -a -t f '%s' %s", python_pattern, normalized_path)
    
    search.run_search({
        on_result = function(result)
            table.insert(results, result)
        end,
        on_complete = function()
            done = true
        end
    }, { args = search_cmd })
    
    wait_for(function() return done end)
    
    -- Check that we found different types of venvs
    local found_types = {
        poetry = false,
        pyenv = false,
        pipenv = false,
        hatch = false,
        conda = false,
    }
    
    for _, result in ipairs(results) do
        if result.path:match("poetry") then
            found_types.poetry = true
        elseif result.path:match("pyenv") then
            found_types.pyenv = true
        elseif result.path:match("pipenv") then
            found_types.pipenv = true
        elseif result.path:match("hatch") then
            found_types.hatch = true
        elseif result.path:match("conda") then
            found_types.conda = true
        end
    end
    
    local missing = {}
    for type_name, found in pairs(found_types) do
        if not found then
            table.insert(missing, type_name)
        end
    end
    
    if #missing > 0 then
        print("✗ Test FAILED: Missing venv types: " .. table.concat(missing, ", "))
        cleanup_test_dir()
        return false
    end
    
    print("✓ Test PASSED: Found all venv types (poetry, pyenv, pipenv, hatch, conda)")
    cleanup_test_dir()
    return true
end

---Test 10: Search with $FD variable substitution
function M.test_fd_variable_substitution()
    print("\n=== Test 10: $FD variable substitution ===")
    
    local test_dir = setup_test_directories()
    local results = {}
    local done = false
    
    -- Use $FD which should be substituted with fd binary name
    local normalized_path = test_dir:gsub("\\", "/")
    local python_pattern = get_python_name() .. "$"
    -- This command uses $FD which will be replaced by the search module
    local search_cmd = string.format("$FD -H -a -t f '%s' %s/project1", python_pattern, normalized_path)
    
    print("  Search command with $FD: " .. search_cmd)
    
    search.run_search({
        on_result = function(result)
            table.insert(results, result)
        end,
        on_complete = function()
            done = true
        end
    }, { args = search_cmd })
    
    wait_for(function() return done end)
    
    if #results == 0 then
        print("✗ Test FAILED: $FD variable not substituted correctly")
        cleanup_test_dir()
        return false
    end
    
    print("✓ Test PASSED: $FD variable substitution works")
    cleanup_test_dir()
    return true
end

---Run all tests (concise output)
-- Prints a single-line result per test (checkmark for pass, X for fail) and a short summary.
function run_all_tests()
    local orig_print = print

    -- Table of tests with friendly names
    local tests = {
        { name = "Test 1: Find python executables", fn = M.test_find_python_executables },
        { name = "Test 2: Verify result structure", fn = M.test_result_structure },
        { name = "Test 3: Search can be stopped", fn = M.test_search_can_be_stopped },
        { name = "Test 4: Interactive search", fn = M.test_interactive_search },
        { name = "Test 5: Search finds hidden directories", fn = M.test_find_hidden_directories },
        { name = "Test 6: Sequential searches", fn = M.test_sequential_searches },
        { name = "Test 7: Path with spaces", fn = M.test_path_with_spaces },
        { name = "Test 8: $CWD substitution", fn = M.test_variable_substitution_cwd },
        { name = "Test 9: Different venv types", fn = M.test_different_venv_types },
        { name = "Test 10: $FD substitution", fn = M.test_fd_variable_substitution },
    }

    local passed = 0
    local failed = 0

    -- Run each test while capturing any verbose prints; then emit a single-line result.
    for _, t in ipairs(tests) do
        local name = t.name
        -- Capture printed output in buffer to avoid noisy logs
        local buf = {}
        local function capture_print(...)
            local parts = {}
            for i = 1, select("#", ...) do
                parts[#parts + 1] = tostring(select(i, ...))
            end
            buf[#buf + 1] = table.concat(parts, "\t")
        end

        -- Override global print temporarily
        print = capture_print

        local ok, err = pcall(t.fn)

        -- Restore original print
        print = orig_print

        if ok then
            orig_print(string.format("✓ %s", name))
            passed = passed + 1
        else
            -- Include a short snippet of captured output if available for debugging
            local snippet = buf[1] and (" | output: " .. (buf[1]:gsub("\n", " "))) or ""
            orig_print(string.format("✗ %s: %s%s", name, tostring(err), snippet))
            failed = failed + 1
        end
    end

    -- Summary line
    orig_print(string.format("Results: %d passed, %d failed", passed, failed))

    return failed == 0
end

-- Export functions
_G.run_all_tests = run_all_tests
_G.cleanup_test_dir = cleanup_test_dir

print([[
VenvSelector Search Test Suite Loaded (minimal output)

Run the concise runner:
  :lua run_all_tests()   -- prints one-line result per test and a short summary

If you need verbose output for debugging, call the individual tests directly.
]])

return M