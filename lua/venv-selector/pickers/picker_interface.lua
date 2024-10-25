local log = require("venv-selector.logger")
local path = require("venv-selector.path")
local config = require("venv-selector.config")

local PickerInterface = {}
PickerInterface.__index = PickerInterface

function PickerInterface.new()
    local self = setmetatable({}, PickerInterface)
    self.results = {}
    return self
end

function PickerInterface:insert_result(row)
    log.debug("Result:")
    log.debug(row)

    table.insert(self.results, row)
    self:update_results()
end

function PickerInterface:get_sorter()
    local sorters = require("telescope.sorters")
    local conf = require("telescope.config").values

    local choices = {
        ["character"] = function()
            return conf.file_sorter()
        end,
        ["substring"] = function()
            return sorters.get_substr_matcher()
        end,
    }

    return choices[config.user_settings.options.telescope_filter_type]
end

function PickerInterface:hl_active_venv(entry)
    local icon_highlight = "VenvSelectActiveVenv"
    if entry.path == path.current_python_path then
        return icon_highlight
    end
    return nil
end

function PickerInterface:draw_icons_for_types(entry)
    if vim.tbl_contains({
        "cwd",
        "workspace",
        "file",
    }, entry.source) then
        return "󰥨"
    elseif
        vim.tbl_contains({
            "virtualenvs",
            "hatch",
            "poetry",
            "pyenv",
            "anaconda_envs",
            "anaconda_base",
            "miniconda_envs",
            "miniconda_base",
            "pipx",
        })
    then
        return ""
    else
        return "" -- user created venv icon
    end
end

function PickerInterface:make_entry_maker()
    --implementation details
end

function PickerInterface:remove_dups()
    -- If a venv is found both by another search AND (cwd or file) search, then keep the one found by another search.
    local seen = {}
    local filtered_results = {}

    for _, v in ipairs(self.results) do
        if not seen[v.name] then
            seen[v.name] = v
        else
            local prev_entry = seen[v.name]
            if
                (v.source == "file" or v.source == "cwd")
                and (prev_entry.source ~= "file" and prev_entry.source ~= "cwd")
            then
            -- Current item has less priority, do not add it
            elseif
                (prev_entry.source == "file" or prev_entry.source == "cwd")
                and (v.source ~= "file" and v.source ~= "cwd")
            then
                -- Previous item has less priority, replace it
                seen[v.name] = v
            end
        end
    end

    for _, entry in pairs(seen) do
        table.insert(filtered_results, entry)
    end

    self.results = filtered_results
end

function PickerInterface:sort_results()
    local selected_python = path.current_python_path
    local current_file_dir = vim.fn.expand("%:p:h")

    log.debug("Calculating path similarity based on: '" .. current_file_dir .. "'")
    -- Normalize path by converting all separators to a common one (e.g., '/')
    local function normalize_path(path)
        return path:gsub("\\", "/")
    end

    -- Calculate the path similarity
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

    log.debug("Sorting results on path similarity.")
    table.sort(self.results, function(a, b)
        -- Check for 'selected_python' match
        local a_is_selected = a.path == selected_python
        local b_is_selected = b.path == selected_python
        if a_is_selected and not b_is_selected then
            return true
        elseif not a_is_selected and b_is_selected then
            return false
        end

        -- Compare based on path similarity
        local sim_a = path_similarity(a.path, current_file_dir)
        local sim_b = path_similarity(b.path, current_file_dir)
        if sim_a ~= sim_b then
            return sim_a > sim_b
        end

        -- Fallback to alphabetical sort
        return a.name > b.name
    end)
end

function PickerInterface:update_results()
    vim.warn("show method not implemented")
end

function PickerInterface:open()
    vim.warn("show method not implemented")
end

return PickerInterface
