local gui_utils = require("venv-selector.gui.utils")
local config = require("venv-selector.config")

local M = {}
M.__index = M

local H = {}

-- Create a namespace for extmarks
-- This is used to highlight the active virtual environment in the results
H.ns_id = vim.api.nvim_create_namespace("MiniPickVenvSelect")

function M.new()
    local self = setmetatable({ results = {} }, M)

    -- Setup highlight groups for marker color
    local marker_color = config.user_settings.options.selected_venv_marker_color or
    config.user_settings.options.telescope_active_venv_color
    vim.api.nvim_set_hl(0, "VenvSelectMarker", { fg = marker_color })

    return self
end

function M:insert_result(result)
    table.insert(self.results, result)
end

function M:search_done()
    local mini_pick = require("mini.pick")
    self.results = gui_utils.remove_dups(self.results)
    gui_utils.sort_results(self.results)

    mini_pick.start({
        source = {
            -- Name of the source, used for display purposes
            name = "Virtual environments",
            -- List of virtual environments
            items = self.results,
            -- Function to preview venvs
            preview = function(buf_id, item)
                local lines = {
                    "Source: " .. item.source,
                    "Name: " .. item.name,
                }
                -- Get pyvenv.cfg file if it exists
                -- To add more information to the preview
                local pyenv_file = vim.fs.normalize(vim.fs.joinpath(item.path, "../../pyvenv.cfg"))
                if vim.fn.filereadable(pyenv_file) == 1 then
                    local content = vim.fn.readfile(pyenv_file)
                    for _, line in ipairs(content) do
                        table.insert(lines, line)
                    end
                end
                -- Update the buffer with the preview content
                vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
            end,
            -- Function for rendering list of venvs
            show = function(buf_id, items_arr, query)
                local lines = {}
                local columns = gui_utils.get_picker_columns()

                -- Format each item as a string based on configured columns
                for _, item in ipairs(items_arr) do
                    local hl = gui_utils.hl_active_venv(item)
                    local marker_icon = config.user_settings.options.selected_venv_marker_icon or
                    config.user_settings.options.icon or "✔"

                    -- Prepare column data
                    local column_data = {
                        marker = hl and marker_icon or " ",
                        search_icon = gui_utils.draw_icons_for_types(item.source),
                        search_name = string.format("%-15s", item.source),
                        search_result = item.name
                    }

                    -- Build line based on configured column order
                    local parts = {}
                    for _, col in ipairs(columns) do
                        if column_data[col] then
                            table.insert(parts, column_data[col])
                        end
                    end
                    table.insert(lines, table.concat(parts, "  "))
                end

                -- Set the buffer lines to the formatted items
                vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
                -- Remove previous highlight extmarks
                pcall(vim.api.nvim_buf_clear_namespace, buf_id, H.ns_id, 0, -1)

                -- Add new extmarks for marker highlighting
                for i, item in ipairs(items_arr) do
                    local hl = gui_utils.hl_active_venv(item)
                    if hl ~= nil then
                        -- Find marker position in the configured columns
                        local marker_col = 0
                        for j, col in ipairs(columns) do
                            if col == "marker" then
                                break
                            elseif column_data[col] then
                                -- Add length of previous column + 2 spaces
                                marker_col = marker_col + vim.fn.strwidth(column_data[col]) + 2
                            end
                        end

                        -- Highlight the marker
                        pcall(vim.api.nvim_buf_set_extmark, buf_id, H.ns_id, i - 1, marker_col, {
                            end_col = marker_col + vim.fn.strwidth(marker_icon),
                            hl_group = "VenvSelectMarker",
                        })
                    end
                end
            end,
            -- Function to handle selection of a venv
            choose = function(item)
                gui_utils.select(item)
            end,
        },
    })
end

return M
