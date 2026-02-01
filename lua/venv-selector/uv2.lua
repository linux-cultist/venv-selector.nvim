local M = {}


local path_mod = require("venv-selector.path")

local has_uv = vim.fn.executable("uv") == 1
local group = vim.api.nvim_create_augroup("VenvSelectorUvDetect", { clear = true })

---Check if a buffer contains PEP-723 script metadata
---@param bufnr integer The buffer number
---@return boolean true if PEP-723 metadata is found
function M.is_uv_buffer(bufnr)
    if vim.bo[bufnr].buftype ~= "" then return false end
    if vim.bo[bufnr].filetype ~= "python" then return false end

    -- PEP 723 block starts with "# /// script" and ends with "# ///"
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 200, false)
    local seen_start = false

    for _, line in ipairs(lines) do
        if not seen_start then
            if line:match("^%s*#%s*///%s*script%s*$") then
                seen_start = true
            end
        else
            if line:match("^%s*#%s*///%s*$") then
                return true
            end
        end
    end

    return false
end

---@param bufnr integer
---@param event string
local function log_uv_detection(bufnr, event)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    local name = vim.api.nvim_buf_get_name(bufnr)
    local uv = M.is_uv_buffer(bufnr)

    require("venv-selector.logger").debug(
        ("uv-detect %s bufnr=%d uv=%s file=%s"):format(event, bufnr, tostring(uv), name)
    )
end

---@param prefix string
---@param text string|nil
local function log_multiline(prefix, text)
    if not text or text == "" then return end
    local log = require("venv-selector.logger")
    for line in text:gmatch("[^\r\n]+") do
        log.debug(prefix .. line)
    end
end

---Run 'uv sync' for a buffer's script
---@param bufnr integer
---@param done? fun(ok: boolean)
local function run_uv_sync_for_buffer(bufnr, done)
    if has_uv == false then
        require("venv-selector.logger").debug("uv not found.")
        if done then done(false) end
        return
    end
    local current_file = vim.api.nvim_buf_get_name(bufnr)
    if current_file == "" then
        if done then done(false) end
        return
    end
    local cmd = { "uv", "sync", "--script", current_file }
    require("venv-selector.logger").debug("Running uv command: " .. table.concat(cmd, " "))
    vim.system(cmd, {
        text = true,
        cwd = vim.fn.fnamemodify(current_file, ":h"),
    }, function(res)
        vim.schedule(function()
            local out = (res.stderr and res.stderr ~= "") and res.stderr or res.stdout
            log_multiline("uv sync: ", out)
            if res.code ~= 0 then
                vim.notify(out or "uv sync failed", vim.log.levels.ERROR, { title = "VenvSelector" })
                if done then done(false) end
                return
            end
            if done then done(true) end
        end)
    end)
end

---Run 'uv python find' and activate the result
---@param bufnr integer
---@param done? fun(ok: boolean, python_path?: string)
local function run_uv_python_find_and_activate(bufnr, done)
    if has_uv == false then
        require("venv-selector.logger").debug("uv not found.")
        if done then done(false) end
        return
    end
    local current_file = vim.api.nvim_buf_get_name(bufnr)
    if current_file == "" or has_uv == false then
        if done then done(false) end
        return
    end
    local cmd = { "uv", "python", "find", "--script", current_file }
    require("venv-selector.logger").debug("Running uv command: " .. table.concat(cmd, " "))
    vim.system(cmd, {
        text = true,
        cwd = vim.fn.fnamemodify(current_file, ":h"),
    }, function(res)
        vim.schedule(function()
            local out = (res.stderr and res.stderr ~= "") and res.stderr or res.stdout
            if res.code ~= 0 or not out or out == "" then
                if done then done(false) end
                return
            end

            local python_path
            for line in out:gmatch("[^\r\n]+") do
                if line and line ~= "" then
                    python_path = line; break
                end
            end
            if not python_path or python_path == "" then
                if done then done(false) end
                return
            end

            -- Activate immediately for first-time resolution (or if it differs)
            if path_mod.current_python_path ~= python_path then
                require("venv-selector.venv").activate(python_path, "uv", false)
            end

            if done then done(true, python_path) end
        end)
    end)
end

---@param bufnr integer
local function run_uv_flow(bufnr)
    run_uv_sync_for_buffer(bufnr, function(_sync_ok)
        run_uv_python_find_and_activate(bufnr, function(ok, python_path)
            vim.b[bufnr].venv_selector_uv_running = false
            if not ok or not python_path or python_path == "" then return end

            vim.b[bufnr].venv_selector_uv_last_tick = vim.b[bufnr].changedtick or 0
            vim.b[bufnr].venv_selector_uv_last_python = python_path
        end)
    end)
end


---Check if buffer content changed and run uv flow if needed
---@param bufnr integer
function M.run_uv_flow_if_needed(bufnr)
    require("venv-selector.logger").debug("run_uv_flow_if_needed")
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    if not M.is_uv_buffer(bufnr) then return end

    local tick = vim.b[bufnr].changedtick or 0
    if vim.b[bufnr].venv_selector_uv_last_tick == tick then
        return -- content unchanged -> don't rerun uv commands
    end

    if vim.b[bufnr].venv_selector_uv_running then return end
    vim.b[bufnr].venv_selector_uv_running = true

    run_uv_flow(bufnr)
end

---Ensure the correct venv is activated for a uv buffer
---@param bufnr integer
function M.ensure_uv_buffer_activated(bufnr)
    require("venv-selector.logger").debug("ensure_uv_buffer_activated")
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    if not M.is_uv_buffer(bufnr) then return end

    local last_python = vim.b[bufnr].venv_selector_uv_last_python
    if last_python and last_python ~= "" then
        if path_mod.current_python_path ~= last_python then
            require("venv-selector.venv").activate(last_python, "uv", false)
        end
        return
    end

    -- No cached python for this buffer yet -> must run uv
    M.run_uv_flow_if_needed(bufnr)
end




return M
