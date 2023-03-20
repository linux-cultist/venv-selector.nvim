local utils = {}

utils.print_table = function(t)
	print(vim.inspect(t))
end

utils.escape_pattern = function(text)
	return text:gsub("([^%w])", "%%%1")
end

utils.remove_last_slash = function(s)
	if string.sub(s, -1, -1) == "/" then
		return string.sub(s, 1, -2)
	end
end

return utils
