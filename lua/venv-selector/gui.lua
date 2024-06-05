local venv = require 'venv-selector.venv'
local path = require 'venv-selector.path'
local config = require('venv-selector.config')

local M = {}

M.results = {}

function M.insert_result(row)
    log.debug("Result:")
    log.debug(row)

    table.insert(M.results, row)
    M.show_results()
end

function M.get_sorter()
    local sorters = require('telescope.sorters')
    local conf = require('telescope.config').values

    local choices = {
        ['character'] = function() return conf.file_sorter() end,
        ['substring'] = function() return sorters.get_substr_matcher() end,
    }

    return choices[config.user_settings.options.telescope_filter_type]
end

function M.make_entry_maker()
    local entry_display = require 'telescope.pickers.entry_display'


    local displayer = entry_display.create {
        separator = ' ',
        items = {
            { width = 2 },
            { width = 110 },
            { width = 2 },
            { width = 20 },
            { width = 0.95 },
        },
    }

    local function draw_icons_for_types(e)
        if vim.tbl_contains({ 'cwd', 'workspace', 'file' }, e.source) then
            return '󰥨'
        elseif vim.tbl_contains({ 'virtualenvs', 'hatch', 'poetry', 'pyenv', 'anaconda_envs', 'anaconda_base', 'pipx' }) then
            return ''
        else
            return '' -- user created venv icon
        end
    end

    local function hl_active_venv(e)
        local icon_highlight = 'VenvSelectActiveVenv'
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
            return displayer {
                { icon,                                                                                         hl_active_venv(entry) },
                { e.name },
                { config.user_settings.options.show_telescope_search_type and draw_icons_for_types(entry) or "" },
                { config.user_settings.options.show_telescope_search_type and e.source or "" }
            }
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
            if (v.source == "file" or v.source == "cwd") and (prev_entry.source ~= "file" and prev_entry.source ~= "cwd") then
                -- Current item has less priority, do not add it
            elseif (prev_entry.source == "file" or prev_entry.source == "cwd") and (v.source ~= "file" and v.source ~= "cwd") then
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
    table.sort(M.results, function(a, b)
        if a.path == selected_python and b.path ~= selected_python then
            return true            -- `a` comes first because it matches `selected_python`
        elseif a.path ~= selected_python and b.path == selected_python then
            return false           -- `b` comes first because it matches `selected_python`
        else
            return a.name > b.name -- Otherwise sort alphabetically
        end
    end)
end

function M.show_results()
    local finders = require 'telescope.finders'
    local actions_state = require 'telescope.actions.state'

    M.sort_results()

    local finder = finders.new_table {
        results = M.results,
        entry_maker = M.make_entry_maker()
    }

    local bufnr = vim.api.nvim_get_current_buf()
    local picker = actions_state.get_current_picker(bufnr)
    if picker ~= nil then
        picker:refresh(finder, { reset_prompt = false })
    end
end

function M.open(in_progress)
    local finders = require 'telescope.finders'
    local pickers = require 'telescope.pickers'
    local actions_state = require 'telescope.actions.state'
    local actions = require 'telescope.actions'


    local title = 'Virtual environments (ctrl-r to refresh)'

    if in_progress == false then
        M.sort_results()
    end

    local finder = finders.new_table {
        results = M.results,
        entry_maker = M.make_entry_maker()
    }

    local opts = {
        prompt_title = title,
        finder = finder,
        layout_strategy = 'horizontal',
        layout_config = {
            height = 0.4,
            width = 140,
            prompt_position = 'top',
        },
        cwd = require('telescope.utils').buffer_dir(),

        sorting_strategy = 'ascending',
        sorter = M.get_sorter()(),
        attach_mappings = function(bufnr, map)
            map('i', '<cr>', function()
                local selected_entry = actions_state.get_selected_entry()
                local activated = false
                if selected_entry ~= nil then
                    activated = venv.activate(config.user_settings.hooks, selected_entry)
                    if activated == true then
                        path.add(path.get_base(selected_entry.path))
                        path.update_python_dap(selected_entry.path)
                        path.save_selected_python(selected_entry.path)

                        if selected_entry.type == "anaconda" then
                            venv.unset_env("VIRTUAL_ENV")
                            venv.set_env(selected_entry.path, "CONDA_PREFIX")
                        else
                            venv.unset_env("CONDA_PREFIX")
                            venv.set_env(selected_entry.path, "VIRTUAL_ENV")
                        end
                    end
                end
                actions.close(bufnr)
            end)

            map('i', '<C-r>', function()
                M.results = {}
                local search = require 'venv-selector.search'
                search.New(nil)
            end)

            return true
        end,
    }
    pickers.new({}, opts):find()
end

return M
