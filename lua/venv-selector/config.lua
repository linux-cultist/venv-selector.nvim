-- lua/venv-selector/config.lua
--
-- Configuration and defaults for venv-selector.nvim.
--
-- Responsibilities:
-- - Define typed configuration shapes (Options / Settings / Searches).
-- - Provide OS-specific default search commands (fd-based discovery).
-- - Provide default options and cache location.
-- - Finalize settings:
--     - Merge shell defaults
--     - Auto-detect fd binary name
--     - Populate default searches (if user didn't specify any)
--     - Inject default hook(s) if user didn't provide hooks
-- - Store user configuration (deep-merge) and expose getters.
--
-- Design notes:
-- - This module intentionally avoids hard-requiring other modules at load time
--   where it might create cycles; e.g. default hook is injected via pcall(require)
--   inside ensure_default_hooks().
-- - fd_binary_name is computed during finalize_settings so it is always available
--   to the search layer without repeated detection calls.

require("venv-selector.types")

local M = {}

local uv = vim.uv

-- ============================================================================
-- Helpers
-- ============================================================================

---Return the first available fd executable name, or nil if none found.
---Supports common distro naming variants (fd, fdfind, fd_find).
---
---@return string|nil fd_name
local function find_fd_command_name()
    for _, cmd in ipairs({ "fd", "fdfind", "fd_find" }) do
        if vim.fn.executable(cmd) == 1 then
            return cmd
        end
    end
    return nil
end

---Build default shell settings from current Neovim options.
---These defaults are merged with any user-provided overrides during finalize_settings().
---
---@return table shell_settings
local function default_shell_settings()
    return {
        shellcmdflag = vim.o.shellcmdflag,
        shell = vim.o.shell,
    }
end

-- ============================================================================
-- Default searches
-- ============================================================================

---Return OS-specific default search definitions.
---These searches are fd-based and expanded by search.lua with $FD/$CWD/$WORKSPACE_PATH/$FILE_DIR.
---
---Notes:
--- - Windows searches use python.exe and Scripts\\python.exe patterns.
--- - Mac/Linux searches use regex forms like '/bin/python$' depending on expected layout.
--- - "type = anaconda" is used to mark conda-derived environments for env var handling.
---
---@return venv-selector.SearchCommands searches
function M.get_default_searches()
    local system = (uv.os_uname() or {}).sysname

    if system == "Windows_NT" then
        return {
            hatch = {
                command =
                "$FD python.exe $HOME\\AppData\\Local\\hatch\\env\\virtual --no-ignore-vcs --full-path --color never",
            },
            poetry = {
                command =
                "$FD python.exe$ $HOME\\AppData\\Local\\pypoetry\\Cache\\virtualenvs --no-ignore-vcs --full-path --color never",
            },
            pyenv = {
                command =
                "$FD python.exe$ $HOME\\.pyenv\\pyenv-win\\versions $HOME\\.pyenv-win-venv\\envs --no-ignore-vcs -E Lib",
            },
            pipenv = {
                command = "$FD python.exe$ $HOME\\.virtualenvs --no-ignore-vcs --full-path --color never",
            },
            pixi = {
                command =
                "$FD python.exe$ $HOME\\.pixi $CWD\\.pixi -HI --no-ignore-vcs --full-path -a --color never",
            },
            anaconda_envs = {
                command = "$FD python.exe$ $HOME\\anaconda3\\envs --no-ignore-vcs --full-path -a -E Lib",
                type = "anaconda",
            },
            anaconda_base = {
                command = "$FD anaconda3\\\\python.exe$ $HOME\\anaconda3 --no-ignore-vcs --full-path -a --color never",
                type = "anaconda",
            },
            miniconda_envs = {
                command = "$FD python.exe$ $HOME\\miniconda3\\envs --no-ignore-vcs --full-path -a -E Lib",
                type = "anaconda",
            },
            miniconda_base = {
                command = "$FD miniconda3\\\\python.exe$ $HOME\\miniconda3 --no-ignore-vcs --full-path -a --color never",
                type = "anaconda",
            },
            pipx = {
                command = "$FD Scripts\\\\python.exe$ $HOME\\pipx\\venvs --no-ignore-vcs --full-path -a --color never",
            },
            cwd = {
                command = "$FD Scripts\\\\python.exe$ $CWD --full-path --color never -HI -a -L",
            },
            workspace = {
                command = "$FD Scripts\\\\python.exe$ $WORKSPACE_PATH --full-path --color never -HI -a -L",
            },
            file = {
                command = "$FD Scripts\\\\python.exe$ $FILE_DIR --full-path --color never -HI -a -L",
            },
        }
    elseif system == "Darwin" then
        return {
            virtualenvs = {
                command = "$FD 'python$' ~/.virtualenvs --no-ignore-vcs --color never",
            },
            hatch = {
                command =
                "$FD 'python$' ~/Library/Application\\\\ Support/hatch/env/virtual --no-ignore-vcs --color never -E '*-build*'",
            },
            poetry = {
                command = "$FD '/bin/python$' ~/Library/Caches/pypoetry/virtualenvs --no-ignore-vcs --full-path",
            },
            pyenv = {
                command =
                "$FD '/bin/python$' ~/.pyenv/versions --no-ignore-vcs --full-path --color never -E pkgs/ -E envs/ -L",
            },
            pipenv = {
                command = "$FD '/bin/python$' ~/.local/share/virtualenvs --no-ignore-vcs --full-path --color never",
            },
            pixi = {
                command = "$FD '/bin/python$' ~/.pixi/envs $PIXI_HOME -HI --no-ignore-vcs --full-path --color never",
            },
            anaconda_envs = {
                command = "$FD 'bin/python$' ~/.conda/envs --no-ignore-vcs --full-path --color never",
                type = "anaconda",
            },
            anaconda_base = {
                command = "$FD '/python$' /opt/anaconda/bin --full-path --color never",
                type = "anaconda",
            },
            miniconda_envs = {
                command = "$FD 'bin/python$' ~/miniconda3/envs --no-ignore-vcs --full-path --color never",
                type = "anaconda",
            },
            miniconda_base = {
                command = "$FD '/python$' ~/miniconda3/bin --no-ignore-vcs --full-path --color never",
                type = "anaconda",
            },
            pipx = {
                command =
                "$FD '/bin/python$' ~/.local/share/pipx/venvs ~/.local/pipx/venvs --no-ignore-vcs --full-path --color never",
            },
            cwd = {
                command =
                "$FD '/bin/python$' '$CWD' --full-path --color never -HI -a -L -E /proc -E .git/ -E .wine/ -E .steam/ -E Steam/ -E site-packages/",
            },
            workspace = {
                command = "$FD '/bin/python$' '$WORKSPACE_PATH' --full-path --color never -E /proc -HI -a -L",
            },
            file = {
                command = "$FD '/bin/python$' '$FILE_DIR' --full-path --color never -E /proc -HI -a -L",
            },
        }
    else
        -- Linux / other UNIX
        return {
            virtualenvs = {
                command = "$FD 'python$' ~/.virtualenvs --no-ignore-vcs --color never",
            },
            hatch = {
                command = "$FD 'python$' ~/.local/share/hatch --no-ignore-vcs --color never -E '*-build*'",
            },
            poetry = {
                command = "$FD '/bin/python$' ~/.cache/pypoetry/virtualenvs --no-ignore-vcs --full-path",
            },
            pyenv = {
                command =
                "$FD '/bin/python$' ~/.pyenv/versions --no-ignore-vcs --full-path --color never -E pkgs/ -E envs/ -L",
            },
            pipenv = {
                command = "$FD '/bin/python$' ~/.local/share/virtualenvs --no-ignore-vcs --full-path --color never",
            },
            pixi = {
                command = "$FD '/bin/python$' ~/.pixi/envs $PIXI_HOME -HI --no-ignore-vcs --full-path --color never",
            },
            anaconda_envs = {
                command = "$FD 'bin/python$' ~/.conda/envs --no-ignore-vcs --full-path --color never",
                type = "anaconda",
            },
            anaconda_base = {
                command = "$FD '/python$' /opt/anaconda/bin --full-path --color never",
                type = "anaconda",
            },
            miniconda_envs = {
                command = "$FD 'bin/python$' ~/miniconda3/envs --no-ignore-vcs --full-path --color never",
                type = "anaconda",
            },
            miniconda_base = {
                command = "$FD '/python$' ~/miniconda3/bin --no-ignore-vcs --full-path --color never",
                type = "anaconda",
            },
            pipx = {
                command =
                "$FD '/bin/python$' ~/.local/share/pipx/venvs ~/.local/pipx/venvs --no-ignore-vcs --full-path --color never",
            },
            cwd = {
                command =
                "$FD '/bin/python$' '$CWD' --full-path --color never -HI -a -L -E /proc -E .git/ -E .wine/ -E .steam/ -E Steam/ -E site-packages/",
            },
            workspace = {
                command = "$FD '/bin/python$' '$WORKSPACE_PATH' --full-path --color never -E /proc -HI -a -L",
            },
            file = {
                command = "$FD '/bin/python$' '$FILE_DIR' --full-path --color never -E /proc -HI -a -L",
            },
        }
    end
end

-- ============================================================================
-- Defaults
-- ============================================================================

---Default plugin settings used when the user does not override values.
---@type venv-selector.Settings
local default_settings = {
    cache = {
        file = "~/.cache/venv-selector/venvs3.json",
    },

    -- Hooks are kept as a table; if empty, a default hook is injected at finalize time.
    hooks = {},

    options = {
        on_venv_activate_callback = nil,
        enable_default_searches = true,
        enable_cached_venvs = true,
        cached_venv_automatic_activation = true,
        activate_venv_in_terminal = true,
        set_environment_variables = true,
        notify_user_on_venv_activation = false,
        override_notify = true,
        search_timeout = 5,
        debug = false,
        fd_binary_name = nil, -- filled in by finalize_settings()
        require_lsp_activation = true,
        on_telescope_result_callback = nil,
        picker_filter_type = "substring",
        selected_venv_marker_color = "#00FF00",
        selected_venv_marker_icon = "✔",
        picker_icons = {},
        picker_columns = { "marker", "search_icon", "search_name", "search_result" },
        picker = "auto",
        statusline_func = { nvchad = nil, lualine = nil },
        show_telescope_search_type = false,
        picker_options = {
            snacks = {
                layout = { preset = "select" },
            },
        },
        shell = default_shell_settings(),
    },

    -- Filled in by finalize_settings() if missing/empty.
    search = {},
}


-- ============================================================================
-- Finalization steps (hooks, fd detection, searches)
-- ============================================================================

---Ensure a default hook exists if the user did not provide any hooks.
---This keeps the configuration "just works" by default, while allowing users
---to supply their own hooks list.
---
---Implementation detail:
--- - Uses pcall(require, ...) to avoid config<->hooks require cycles at module load time.
---
---@param s venv-selector.Settings
local function ensure_default_hooks(s)
    -- Normalize to table.
    if type(s.hooks) ~= "table" then
        s.hooks = {}
    end

    -- User provided hooks (non-empty): respect them.
    if #s.hooks > 0 then
        return
    end

    -- Default hook (lazy require).
    local ok, hooks_mod = pcall(require, "venv-selector.hooks")
    if ok and hooks_mod and type(hooks_mod.dynamic_python_lsp_hook) == "function" then
        s.hooks = { hooks_mod.dynamic_python_lsp_hook }
    else
        s.hooks = {}
    end
end

---Finalize settings after merge:
--- - Merge shell defaults
--- - Auto-detect fd binary
--- - Populate searches if missing/empty
--- - Ensure default hooks if user provided none
---
---@param s venv-selector.Settings
---@return venv-selector.Settings finalized
local function finalize_settings(s)
    -- Shell defaults: merge user overrides onto current Neovim defaults.
    s.options.shell = vim.tbl_deep_extend("force", default_shell_settings(), s.options.shell or {})

    -- fd auto-detect.
    if not s.options.fd_binary_name or s.options.fd_binary_name == "" then
        s.options.fd_binary_name = find_fd_command_name()
    end

    -- Default searches if missing/empty.
    if not s.search or vim.tbl_isempty(s.search) then
        s.search = M.get_default_searches()
    end

    -- Default hooks if none provided.
    ensure_default_hooks(s)



    return s
end

-- ============================================================================
-- State + public API
-- ============================================================================

---Current effective user settings (defaults, optionally merged with user overrides).
---@type venv-selector.Settings
M.user_settings = finalize_settings(vim.deepcopy(default_settings))

---Store user settings (deep-merge with defaults) and finalize.
---
---@param settings venv-selector.Settings|nil User overrides (can be nil)
---@return venv-selector.Settings effective_settings
function M.store(settings)
    local log = require("venv-selector.logger")
    log.debug("User plugin settings: ", settings, "")

    -- Merge onto defaults, then finalize derived fields.
    M.user_settings = vim.tbl_deep_extend("force", default_settings, settings or {})
    M.user_settings = finalize_settings(M.user_settings)

    return M.get_user_settings()
end

---Get the current Options table (convenience helper).
---
---@return venv-selector.Options
function M.get_user_options()
    return M.user_settings.options
end

---Get the current full Settings table (hooks/options/search/cache).
---
---@return venv-selector.Settings
function M.get_user_settings()
    return M.user_settings
end

---Return a finalized copy of the defaults (no user overrides).
---
---@return venv-selector.Settings defaults
function M.get_defaults()
    return finalize_settings(vim.deepcopy(default_settings))
end

return M
