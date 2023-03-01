local utils = {}

utils.print_table = function(t)
	print(vim.inspect(t))
end

utils.merge_tables = function(t1, t2)
	if t2 == nil then
		return t1
	end

	for k, v in pairs(t2) do
		if type(v) == "table" then
			t1[k] = utils.merge_tables(t1[k], t2[k])
		else
			t1[k] = v
		end
	end

	return t1
end

return utils
