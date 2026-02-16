-- lua/venv-selector/user_commands.lua
--
-- Neovim user commands for venv-selector.nvim.
--
-- Responsibilities:
-- - Define :VenvSelect to open the picker UI and start a search.
-- - Define :VenvSelectLog to toggle the plugin log buffer (requires debug=true).
-- - Optionally define :VenvSelectCached when automatic cached activation is disabled,
--   allowing manual restore of the cached venv for the current buffer/project.
--
-- Notes:
-- - Commands are registered during plugin setup (init.lua -> user_commands.register()).
-- - For :VenvSelect, `opts` are passed through to gui.open(), and ultimately to search.run_search().
-- - The cached command is only created when auto-activation is disabled to avoid redundancy.

require("venv-selector.types")

---@class venv-selector.UserCommandsModule
---@field register fun()
local M = {}

---Register all venv-selector user commands.
---Safe to call once during setup.
function M.register()
    -- Open picker UI and run configured searches (or interactive search if args provided).
    vim.api.nvim_create_user_command("VenvSelect", function(opts)
        ---@type venv-selector.GuiOpenOpts
        local gui_opts = {
            args = opts.args,
        }
        require("venv-selector.gui").open(gui_opts)
    end, { nargs = "*", desc = "Activate venv" })

    -- Toggle the VenvSelect log buffer (requires options.log_level ~= "none").
    vim.api.nvim_create_user_command("VenvSelectLog", function()
        local log = require("venv-selector.logger")
        local rc = log.toggle()
        if rc == 1 then
            vim.notify(
                "VenvSelect logging is disabled. Set options.log_level (e.g. 'info', 'debug', 'trace').",
                vim.log.levels.INFO,
                { title = "VenvSelect" }
            )
        end
    end, { desc = "Toggle the VenvSelect log window" })

    -- Read settings at registration time.
    -- This is intentionally done here to avoid config require at top-level during startup.
    local cached_venv = require("venv-selector.cached_venv")

    -- If cached venv auto-activation is disabled, provide a manual command instead.
    if not cached_venv.cache_auto_enabled() and cached_venv.cache_feature_enabled() then
        vim.api.nvim_create_user_command("VenvSelectCached", function()
            local cache = require("venv-selector.cached_venv")
            cache.retrieve()
        end, { nargs = "*", desc = "Activate cached venv for the current cwd" })
    end
end

return M
