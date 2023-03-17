local telescope = {}

telescope.finders = require("telescope.finders")
telescope.conf = require("telescope.config").values
telescope.pickers = require("telescope.pickers")
telescope.actions_state = require("telescope.actions.state")
telescope.actions = require("telescope.actions")

return telescope
