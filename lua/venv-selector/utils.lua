local M = {}

local config = require("venv-selector.config")
local msg_prefix = "VenvSelect: "

M.notify = function(msg)
	vim.notify(msg_prefix .. msg, vim.log.levels.INFO, { title = "VenvSelect" })
end

M.error = function(msg)
	vim.notify(msg_prefix .. msg, vim.log.levels.ERROR, { title = "VenvSelect" })
end

M.fd_or_fdfind_exists = function()
	local utils = require("venv-selector.utils")
	local custom_fd = config.settings.fd_binary_name

	if custom_fd ~= nil then
		if vim.fn.executable(custom_fd) == 1 then
			utils.dbg(
				"Setting fd binary to '"
					.. custom_fd
					.. "' since it was found on system and requested by user instead of fd."
			)
			config.settings.fd_binary_name = custom_fd
			return true
		else
			utils.error("You have set fd_binary_name to '" .. custom_fd .. "' but it doesnt exist on your system.")
			return false
		end
	end

	local fd_exists = vim.fn.executable("fd")
	local fdfind_exists = vim.fn.executable("fdfind")
	local fd_find_exists = vim.fn.executable("fd-find")

	if fd_exists == 1 then
		config.settings.fd_binary_name = "fd"
		utils.dbg("Setting fd_binary_name to 'fd' since it was found on system.")
		return true
	elseif fdfind_exists == 1 then
		config.settings.fd_binary_name = "fdfind"
		utils.dbg("Setting fd_binary_name to 'fdfind' since it was found on system instead of fd.")
		return true
	elseif fd_find_exists == 2 then
		config.settings.fd_binary_name = "fd-find"
		utils.dbg("Setting fd_binary_name to 'fd-find' since it was found on system instead of fd.")
		return true
	else
		return false
	end
end

M.dbg = function(msg)
	if config.settings.enable_debug_output == false or msg == nil then
		return
	end

	if type(msg) == "string" then
		print(msg_prefix .. msg)
	else
		if type(msg) == "table" then
			print(msg_prefix)
			M.print_table(msg)
		elseif type(msg) == "boolean" then
			print(msg_prefix .. tostring(msg))
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
		local ishatch = path == config.settings.hatch_path
		local expanded_path = vim.fn.expand(path)

		if vim.fn.isdirectory(expanded_path) ~= 0 then
			expanded_path = expanded_path:gsub(" ", "\\ ") -- escape space so paths can have a space
			if ishatch == true then
				-- special handling for hatch
				search_path_string = search_path_string .. expanded_path .. "/*/*" .. " "
			else
				search_path_string = search_path_string .. expanded_path .. " "
			end
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
