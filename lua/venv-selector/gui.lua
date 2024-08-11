local venv = require("venv-selector.venv")
local path = require("venv-selector.path")
local config = require("venv-selector.config")
local log = require("venv-selector.logger")

local M = {}

M.results = {}

function M.insert_result(row)
    log.debug("Result:")
    log.debug(row)

    table.insert(M.results, row)
    M.update_results()
end

function M.get_sorter()
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

function M.make_entry_maker()
    local entry_display = require("telescope.pickers.entry_display")

    local displayer = entry_display.create({
        separator = " ",
        items = {
            { width = 2 },
            { width = 90 },
            { width = 2 },
            { width = 20 },
            { width = 0.95 },
        },
    })

    local function draw_icons_for_types(e)
        if vim.tbl_contains({
            "cwd",
            "workspace",
            "file",
        }, e.source) then
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

    local function hl_active_venv(e)
        local icon_highlight = "VenvSelectActiveVenv"
        if e.path == path.current_python_path then
            return icon_highlight
        end
        return nil
    end

    return function(entry)
        local icon = entry.icon
        entry.value = entry.name
        entry.ordinal = entry.path
        entry.display = function(e)
            return displayer({
                {
                    icon,
                    hl_active_venv(entry),
                },
                { e.name },
                {
                    config.user_settings.options.show_telescope_search_type and draw_icons_for_types(entry) or "",
                },
                {
                    config.user_settings.options.show_telescope_search_type and e.source or "",
                },
            })
        end

        return entry
    end
end

function M.remove_dups()
    -- If a venv is found both by another search AND (cwd or file) search, then keep the one found by another search.
    local seen = {}
    local filtered_results = {}

    for _, v in ipairs(M.results) do
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

    M.results = filtered_results
end

function M.sort_results()
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

    log.debug("Sorting telescope results on path similarity.")
    table.sort(M.results, function(a, b)
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

function M.update_results()
    local finders = require("telescope.finders")
    local actions_state = require("telescope.actions.state")

    local finder = finders.new_table({
        results = M.results,
        entry_maker = M.make_entry_maker(),
    })

    local bufnr = vim.api.nvim_get_current_buf()
    local picker = actions_state.get_current_picker(bufnr)
    if picker ~= nil then
        picker:refresh(finder, { reset_prompt = false })
    end
end

function M.open(in_progress)
    local finders = require("telescope.finders")
    local pickers = require("telescope.pickers")
    local actions_state = require("telescope.actions.state")
    local actions = require("telescope.actions")

    local title = "Virtual environments (ctrl-r to refresh)"

    if in_progress == false then
        M.sort_results()
    end

    local finder = finders.new_table({
        results = M.results,
        entry_maker = M.make_entry_maker(),
    })

    local opts = {
        prompt_title = title,
        finder = finder,
        layout_strategy = "vertical",
        layout_config = {
            height = 0.4,
            width = 120,
            prompt_position = "top",
        },
        cwd = require("telescope.utils").buffer_dir(),

        sorting_strategy = "ascending",
        sorter = M.get_sorter()(),
        attach_mappings = function(bufnr, map)
            map({ "i", "n" }, "<cr>", function()
                local selected_entry = actions_state.get_selected_entry()
                if selected_entry ~= nil then
                    venv.set_source(selected_entry.source)
                    venv.activate(selected_entry.path, selected_entry.type, true)
                end
                actions.close(bufnr)
            end)

            map("i", "<C-r>", function()
                M.results = {}
                local search = require("venv-selector.search")
                search.New(nil)
            end)

            return true
        end,
    }
    pickers.new({}, opts):find()
end

return M
