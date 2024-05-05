local M = {}

function M.get_home_directory()
    if vim.loop.os_uname().sysname == "Windows" then
        return os.getenv("USERPROFILE") -- Windows
    else
        return os.getenv("HOME")        -- Unix-like (Linux, macOS)
    end
end

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

function M.normalize_path(path)
    local parts = {}
    local is_absolute = string.sub(path, 1, 1) == '/'  -- Check if path starts with a '/'
    local path_sep = '/'
    local result = ''

    -- Handle multiple slashes by reducing them to one
    path = path:gsub(path_sep .. '+', path_sep)

    for part in string.gmatch(path, "[^" .. path_sep .. "]+") do
        if part == ".." then
            if #parts > 0 and parts[#parts] ~= ".." then
                -- Only pop the last part if it's not another '..'
                parts[#parts] = nil
            else
                -- If we're at the root or in a relative path, keep '..'
                if not is_absolute or #parts == 0 then
                    table.insert(parts, part)
                end
            end
        elseif part ~= "." then
            -- Skip over any '.' segments (current directory)
            table.insert(parts, part)
        end
    end

    result = table.concat(parts, path_sep)
    -- Ensure we preserve the leading slash if the path was absolute
    if is_absolute and string.sub(result, 1, 1) ~= path_sep then
        result = path_sep .. result
    end

    return result
end



function M.expand_home_path(path)
    local home_dir = M.get_home_directory()
    return path:gsub("~", home_dir)
end

function M.get_base_path(path)
    -- This pattern handles both forward slashes and backslashes
    local pattern = "(.*[/\\])"
    return path:match(pattern)
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
