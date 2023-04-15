local M = {}

local config = require("venv-selector.config")

M.dbg = function(msg)
	local prefix = "VenvSelect: "
	if config.settings.enable_debug_output == false or msg == nil then
		return
	end

	if type(msg) == "string" then
		print(prefix .. msg)
	else
		if type(msg) == "table" then
			print(prefix)
			M.print_table(msg)
		elseif type(msg) == "boolean" then
			print(prefix .. tostring(msg))
		else
			print("Unhandled message type to dbg: message type is " .. type(msg))
		end
	end
end

M.print_table = function(t)
	print(vim.inspect(t))
end

M.escape_pattern = function(text)
	return text:gsub("([^%w])", "%%%1")
end

-- Go up in the directory tree "limit" amount of times, and then returns the path.
M.find_parent_dir = function(dir, limit)
	for subdir in vim.fs.parents(dir) do
		if vim.fn.isdirectory(subdir) then
			if limit > 0 then
				return M.find_parent_dir(subdir, limit - 1)
			else
				break
			end
		end
	end

	return dir
end

-- Creating a regex search path string with all venv names separated by
-- the '|' character. We also make sure that the venv name is an exact match
-- using '^' and '$' so we dont match on paths with the venv name in the middle.
M.create_fd_venv_names_regexp = function(config_venv_name)
	local venv_names = ""

	if type(config_venv_name) == "table" then
		venv_names = venv_names .. "("
		for _, venv_name in pairs(config_venv_name) do
			venv_names = venv_names .. "^" .. venv_name .. "$" .. "|" -- Creates (^venv_name1$ | ^venv_name2$ ) etc
		end
		venv_names = venv_names:sub(1, -2) -- Always remove last '|' since we only want it between words
		venv_names = venv_names .. ")"
	else
		if type(config_venv_name) == "string" then
			venv_names = "^" .. config_venv_name .. "$"
		end
	end

	return venv_names
end

-- Create a search path string to fd command with all paths instead of
-- running fd several times.
M.create_fd_search_path_string = function(paths)
	local search_path_string = ""
	for _, path in pairs(paths) do
		local expanded_path = vim.fn.expand(path)
		if vim.fn.isdirectory(expanded_path) ~= 0 then
			search_path_string = search_path_string .. "--search-path " .. expanded_path .. " "
		end
	end
	return search_path_string
end

-- Remove last slash if it exists, otherwise return the string unmodified
M.remove_last_slash = function(s)
	local last_character = string.sub(s, -1, -1)

	if last_character == "/" or last_character == "\\" then
		return string.sub(s, 1, -2)
	end

	return s
end

--- Checks whether `haystack` string starts with `needle` prefix
--- @type fun(haystack: string, needle: string): boolean
M.starts_with = function(haystack, needle)
	return string.sub(haystack, 1, string.len(needle)) == needle
end

return M
