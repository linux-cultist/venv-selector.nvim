local api = {}
local venv = require("venv-selector.venv")

api.get_active_path = function()
	return venv.current_path
end

api.get_active_venv = function()
	return venv.current_venv
end

return api
