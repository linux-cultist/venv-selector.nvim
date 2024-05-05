local M = {}



function M.merge_settings(defaults, user_settings)
    for key, value in pairs(user_settings) do
        if type(value) == "table" and type(defaults[key]) == "table" then
            -- Check if the table is an array
            if #value > 0 then
                -- Assume it's an array and append items
                for _, item in ipairs(value) do
                    table.insert(defaults[key], item)
                end
            else
                -- It's a dictionary, so merge recursively
                M.merge_settings(defaults[key], value)
            end
        else
            defaults[key] = value
        end
    end
    return defaults
end



function M.print_table(tbl, indent)
    if not indent then indent = 0 end
    for k, v in pairs(tbl) do
        local formatting = string.rep("  ", indent) .. k .. ": "
        if type(v) == "table" then
            print(formatting)
            M.print_table(v, indent + 1)
        else
            print(formatting .. tostring(v))
        end
    end
end

return M
