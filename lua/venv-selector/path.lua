local M = {}

local previous_dir = nil

function M.add(newDir)
    if newDir ~= nil then
        if previous_dir ~= nil then
            M.remove(previous_dir)
        end
        local path = vim.fn.getenv("PATH")
        local path_separator = package.config:sub(1, 1) == '\\' and ';' or ':'
        local clean_dir = M.remove_trailing_slash(newDir)
        local updated_path = clean_dir .. path_separator .. path
        previous_dir = clean_dir
        vim.fn.setenv("PATH", updated_path)
    end
end

function M.remove_trailing_slash(path)
    -- Check if the last character is a slash
    if path:sub(-1) == "/" or path:sub(-1) == "\\" then
        -- Remove the last character
        return path:sub(1, -2)
    end
    return path
end

function M.remove(removalDir)
    local clean_dir = M.remove_trailing_slash(removalDir)
    local path = vim.fn.getenv("PATH")
    local pathSeparator = package.config:sub(1, 1) == '\\' and ';' or ':'
    local paths = {}
    for p in string.gmatch(path, "[^" .. pathSeparator .. "]+") do
        if p ~= clean_dir then
            table.insert(paths, p)
        end
    end
    local updatedPath = table.concat(paths, pathSeparator)
    vim.fn.setenv("PATH", updatedPath)
end

function M.normalize(path)
    local parts = {}
    local is_absolute = string.sub(path, 1, 1) == '/' -- Check if path starts with a '/'
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

function M.get_home_directory()
    local sysname = vim.loop.os_uname().sysname
    dbg(sysname, "sysname")
    if sysname == "Windows_NT" then
        return os.getenv("USERPROFILE") -- Windows
    else
        return os.getenv("HOME")        -- Unix-like (Linux, macOS)
    end
end

function M.expand(path)
    local expanded_path = vim.fn.expand(path)
    return expanded_path
end

function M.get_base(path)
    if path ~= nil then
        -- Check if the path ends with a slash and remove it, unless it's a root path
        if (path:sub(-1) == "/" or path:sub(-1) == "\\") and #path > 1 then
            path = path:sub(1, -2)
        end

        -- Use the pattern to find the base path
        local pattern = "(.*[/\\])"
        local base = path:match(pattern)
        if base then
            -- Remove the trailing slash for the next potential call
            return base:sub(1, -2)
        else
            -- Return nil if no higher directory level can be found
            return nil
        end
    end
end

return M
