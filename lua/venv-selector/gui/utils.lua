local path = require("venv-selector.path")
local log = require("venv-selector.logger")

---@class venv-selector.Options
---@field show_telescope_search_type? boolean

local M = {}

---@param results SearchResult[]
---@return SearchResult[]
function M.remove_dups(results)
    local seen = {}
    local out = {}

    local SOURCE_PRIO = {
        workspace = 30,
        file = 20
    }

    local function key(r)
        return r.path or r.name
    end

    local function prio(r)
        return SOURCE_PRIO[r.source] or 0
    end

    local function is_active(r)
        return M.hl_active_venv(r) ~= nil
    end

    for _, r in ipairs(results) do
        local k = key(r)
        local prev_i = seen[k]

        if not prev_i then
            out[#out + 1] = r
            seen[k] = #out
        else
            local prev = out[prev_i]

            local prev_active, r_active = is_active(prev), is_active(r)
            if prev_active ~= r_active then
                if r_active then
                    out[prev_i] = r
                end
            else
                -- both active or both not active: prefer higher source priority
                local pp, rp = prio(prev), prio(r)
                if rp > pp then
                    out[prev_i] = r
                end
            end
        end
    end

    return out
end

---Sort results (in-place)
---@param results SearchResult[]
function M.sort_results(results)
    local order = {
        "workspace", "file",
        "pixi", "poetry", "pipenv", "virtualenvs",
        "pyenv", "hatch",
        "anaconda_envs", "anaconda_base",
        "miniconda_envs", "miniconda_base",
        "pipx", "cwd"
    }
    local SOURCE_PRIO = {}
    local n = #order
    for i, name in ipairs(order) do
        SOURCE_PRIO[name] = n - i + 1
    end

    local function src_prio(r) return SOURCE_PRIO[r.source] or 0 end

    local selected_python = path.current_python_path
    local current_file_dir = vim.fn.expand("%:p:h")

    local function normalize_path(p) return (p:gsub("\\", "/")) end

    local function path_similarity(path1, path2)
        path1 = normalize_path(path1)
        path2 = normalize_path(path2)
        local segments1 = vim.split(path1, "/")
        local segments2 = vim.split(path2, "/")
        local count = 0
        for i = 1, math.min(#segments1, #segments2) do
            if segments1[i] == segments2[i] then
                count = count + 1
            else
                break
            end
        end
        return count
    end

    table.sort(results, function(a, b)
        -- 0) Active marker first
        local a_active = M.hl_active_venv(a) ~= nil
        local b_active = M.hl_active_venv(b) ~= nil
        if a_active ~= b_active then
            return a_active
        end

        -- 1) Then selected_python match
        local a_is_selected = a.path == selected_python
        local b_is_selected = b.path == selected_python
        if a_is_selected ~= b_is_selected then
            return a_is_selected
        end

        -- 2) Source priority (higher first)
        local pa, pb = src_prio(a), src_prio(b)
        if pa ~= pb then
            return pa > pb
        end

        -- 3) Then path similarity
        local sim_a = path_similarity(a.path, current_file_dir)
        local sim_b = path_similarity(b.path, current_file_dir)
        if sim_a ~= sim_b then
            return sim_a > sim_b
        end

        -- 4) Fallback alphabetical (ascending)
        return (a.name or "") < (b.name or "")
    end)
end

---@param source string
---@return string
function M.draw_icons_for_types(source)
    local config = require("venv-selector.config")

    -- Check for "default" override first
    if config.user_settings.options.picker_icons["default"] then
        return config.user_settings.options.picker_icons["default"]
    end

    -- Check for specific source override
    if config.user_settings.options.picker_icons[source] then
        return config.user_settings.options.picker_icons[source]
    end

    -- Default icons
    if source == "cwd" then
        return "🏠"
    elseif source == "workspace" then
        return "💼"
    elseif source == "file" then
        return "📄"
    elseif source == "virtualenvs" then
        return "🐍"
    elseif source == "hatch" then
        return "🥚"
    elseif source == "poetry" then
        return "📜"
    elseif source == "pyenv" then
        return "⚙️"
    elseif vim.tbl_contains({
            "anaconda_envs",
            "anaconda_base",
        }, source) then
        return "🐊"
    elseif vim.tbl_contains({
            "miniconda_envs",
            "miniconda_base",
        }, source) then
        return "🔬"
    elseif source == "pipx" then
        return "📦"
    else
        return "🐍" -- user created venv icon
    end
end

---@param entry SearchResult
---@return string|nil
function M.hl_active_venv(entry)
    local icon_highlight = "VenvSelectActiveVenv"
    if entry.path == path.current_python_path then
        return icon_highlight
    end
    return nil
end

---@param icon string
---@param source string
---@param name string
---@return string
function M.format_result_as_string(icon, source, name)
    local config = require("venv-selector.config")
    if config.user_settings.options.show_telescope_search_type then
        return string.format("%s %s %s %s", icon, M.draw_icons_for_types(source), source, name)
    else
        return string.format("%s %s", icon, name)
    end
end

---@return string[]
function M.get_picker_columns()
    local config = require("venv-selector.config")
    return config.user_settings.options.picker_columns or { "marker", "search_icon", "search_name", "search_result" }
end

local function pick_target_python_buf()
    -- 1) Prefer alternate buffer (often the file buffer you came from)
    local alt = vim.fn.bufnr("#")
    if alt > 0 and vim.api.nvim_buf_is_valid(alt) then
        if vim.bo[alt].buftype == "" and vim.bo[alt].filetype == "python" then
            return alt
        end
    end

    -- 2) Prefer any loaded python file buffer
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(b)
            and vim.bo[b].buftype == ""
            and vim.bo[b].filetype == "python"
            and vim.api.nvim_buf_get_name(b) ~= "" then
            return b
        end
    end

    -- 3) Fallback: current buffer (may be picker buffer; activation should handle nil root safely)
    return vim.api.nvim_get_current_buf()
end


---@param entry SearchResult|nil
function M.select(entry)
    if entry == nil then return end

    local venv = require("venv-selector.venv")
    venv.set_source(entry.source)

    local bufnr = pick_target_python_buf()

    if type(venv.activate_for_buffer) == "function" then
        venv.activate_for_buffer(entry.path, entry.type, bufnr, { save_cache = true })
    else
        venv.activate(entry.path, entry.type, true)
    end
end

return M
