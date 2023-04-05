return {
	-- Connect user command to main function
	setup_user_commands = function(name, callback, desc)
		vim.api.nvim_create_user_command(name, callback, { desc = desc })
	end,
}
