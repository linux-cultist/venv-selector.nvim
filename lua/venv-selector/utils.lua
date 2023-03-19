local utils = {}

utils.print_table = function(t)
	print(vim.inspect(t))
end

utils.escape_pattern = function(text)
	return text:gsub("([^%w])", "%%%1")
end

return utils
