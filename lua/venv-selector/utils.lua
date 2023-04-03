local utils = {}

utils.print_table = function(t)
	print(vim.inspect(t))
end

utils.escape_pattern = function(text)
	return text:gsub("([^%w])", "%%%1")
end

utils.remove_last_slash = function(s)
	local separator = "\\"
	local sysname = vim.loop.os_uname().sysname
	if sysname == "Linux" or sysname == "Darwin" then
		separator = "/"
	end
	if string.sub(s, -1, -1) == separator then
		return string.sub(s, 1, -2)
	end
  return s
end

return utils
