-- lua/venv-selector/types.lua
--
-- Shared type definitions for venv-selector.nvim.
-- This file is intentionally "require-able" so other modules can pull in annotations
-- without duplicating type blocks everywhere.

local M = {}

---@class venv-selector.SearchResult
---@field path string The file path to the python executable (selected env interpreter)
---@field name string Display name of the environment/interpreter
---@field icon? string Icon to display (picker UI)
---@field type string Type of environment (e.g., "venv", "conda", "uv")
---@field source string Search source that found this result (e.g., "cwd", "workspace", ...)
---@field text? string  -- Optional UI/matcher field (mini.pick, snacks)

---@class venv-selector.SearchCallbacks
---@field on_result fun(result: venv-selector.SearchResult) Called for each result found
---@field on_complete fun() Called when search completes

---@class venv-selector.Picker
---@field insert_result fun(self: venv-selector.Picker, result: venv-selector.SearchResult) Add a result to the picker
---@field search_done fun(self: venv-selector.Picker) Called when search completes

---@class venv-selector.SearchOpts
---@field args string Command arguments for interactive search

---@class venv-selector.SearchConfig
---@field command string The search command to execute (may contain $FD/$CWD/$WORKSPACE_PATH/$FILE_DIR/$CURRENT_FILE)
---@field type? string The type of environment for results produced by this search
---@field on_telescope_result_callback? fun(line: string, source: string): string
---@field on_fd_result_callback? fun(line: string, source: string): string
---@field execute_command? string Fully expanded command actually executed (computed per invocation)
---@field name? string Resolved search name (filled in when job starts)
---@field stderr_output? string[] Collected stderr output lines

---@class venv-selector.ActiveJobState
---@field name string Search name (e.g. "cwd", "workspace")
---@field type? string Env type for results from this job
---@field execute_command? string Final command executed
---@field on_telescope_result_callback? fun(line: string, source: string): string
---@field on_fd_result_callback? fun(line: string, source: string): string
---@field stderr_output? string[]

---@class venv-selector.SnacksItem: venv-selector.SearchResult
---@field text string Snacks matcher text (e.g. "<source> <name>")

---@class venv-selector.SnacksPickerState: venv-selector.Picker
---@field results venv-selector.SnacksItem[] Accumulated items for Snacks
---@field picker any|nil Active Snacks picker instance
---@field _refresh_scheduled boolean True while a refresh timer is pending
---@field _closed boolean True after on_close has fired (prevents further refresh)

---@class venv-selector.NativePickerState: venv-selector.Picker
---@field results venv-selector.SearchResult[] Accumulated entries

---@class venv-selector.MiniPickState: venv-selector.Picker
---@field results venv-selector.SearchResult[]
---@field picker_started boolean
---@field refresh_ms integer
---@field _refresh_scheduled boolean
---@field start_picker fun(self: venv-selector.MiniPickState)
---@field _schedule_push fun(self: venv-selector.MiniPickState)
---@field insert_result fun(self: venv-selector.MiniPickState, result: venv-selector.SearchResult)
---@field search_done fun(self: venv-selector.MiniPickState)

---@class venv-selector.FzfLuaState: venv-selector.Picker
---@field is_done boolean True after search_done() (signals final flush)
---@field queue venv-selector.SearchResult[] Pending items to emit
---@field entries table<string, venv-selector.SearchResult> Map from rendered entry line to SearchResult
---@field is_closed boolean True after picker closes
---@field picker_started boolean (legacy/unused) maintained for compatibility
---@field fzf_cb? fun(entry?: string) fzf feed callback (nil when closed)
---@field _started_emitting boolean True once the initial grace gate has passed
---@field _grace_ms integer Grace period to allow active item to arrive before first emission
---@field _t0 integer Start time (ms) used for grace-period measurement
---@field _flush_scheduled boolean True while a flush is scheduled
---@field _flush_ms integer Delay between flush cycles
---@field _batch_size integer Maximum items emitted per flush cycle
---@field consume_queue fun(self: venv-selector.FzfLuaState)
---@field insert_result fun(self: venv-selector.FzfLuaState, result: venv-selector.SearchResult)
---@field search_done fun(self: venv-selector.FzfLuaState)

---@alias venv-selector.VenvType "venv"|"conda"|"uv"|string

---@class venv-selector.CachedVenvInfo
---@field value string Absolute path to python executable
---@field type venv-selector.VenvType Environment type
---@field source? string Source tag used by venv-selector (e.g. "workspace", "cwd", ...)

---@alias venv-selector.CachedVenvTable table<string, venv-selector.CachedVenvInfo>

---@class venv-selector.CachedVenvModule
---@field ensure_buffer_last_venv_activated fun(bufnr?: integer)
---@field clean_stale_entries fun(cache_tbl: venv-selector.CachedVenvTable|any): venv-selector.CachedVenvTable
---@field handle_automatic_activation fun(done?: fun(activated: boolean))
---@field save fun(python_path: string, venv_type: venv-selector.VenvType, bufnr?: integer)
---@field retrieve fun(bufnr?: integer, done?: fun(activated: boolean))
---@field ensure_cached_venv_activated fun(bufnr?: integer)

---@class venv-selector.SearchCommand
---@field command string The command to execute for finding python interpreters
---@field type? string Optional type identifier (e.g., "anaconda")

---@class venv-selector.SearchCommands
---@field virtualenvs? venv-selector.SearchCommand
---@field hatch? venv-selector.SearchCommand
---@field poetry? venv-selector.SearchCommand
---@field pyenv? venv-selector.SearchCommand
---@field pipenv? venv-selector.SearchCommand
---@field pixi? venv-selector.SearchCommand
---@field anaconda_envs? venv-selector.SearchCommand
---@field anaconda_base? venv-selector.SearchCommand
---@field miniconda_envs? venv-selector.SearchCommand
---@field miniconda_base? venv-selector.SearchCommand
---@field pipx? venv-selector.SearchCommand
---@field cwd? venv-selector.SearchCommand
---@field workspace? venv-selector.SearchCommand
---@field file? venv-selector.SearchCommand

---@alias venv-selector.Hook fun(venv_python: string|nil, env_type: string|nil)

---@class venv-selector.CacheSettings
---@field file string Path to cache file

---@class venv-selector.PickerOptions
---@field snacks? table Snacks picker specific options

---@class venv-selector.Options
---@field on_venv_activate_callback? fun()
---@field enable_default_searches boolean
---@field enable_cached_venvs boolean
---@field cached_venv_automatic_activation boolean
---@field activate_venv_in_terminal boolean
---@field set_environment_variables boolean
---@field notify_user_on_venv_activation boolean
---@field override_notify boolean
---@field search_timeout number
---@field debug boolean
---@field fd_binary_name? string
---@field require_lsp_activation boolean
---@field shell? table
---@field on_telescope_result_callback? fun(filename: string): string
---@field picker_filter_type "substring"|"character"
---@field selected_venv_marker_color string
---@field selected_venv_marker_icon string
---@field picker_icons table<string, string>
---@field picker_columns string[]
---@field picker "telescope"|"fzf-lua"|"native"|"mini-pick"|"snacks"|"auto"
---@field statusline_func table
---@field picker_options venv-selector.PickerOptions
---@field telescope_active_venv_color? string
---@field icon? string
---@field telescope_filter_type? string
---@field show_telescope_search_type? boolean

---@class venv-selector.Settings
---@field cache venv-selector.CacheSettings
---@field hooks venv-selector.Hook[]
---@field options venv-selector.Options
---@field search venv-selector.SearchCommands
---@field detected? table

---@class venv-selector.ConfigModule
---@field user_settings venv-selector.Settings
---@field get_default_searches fun(): venv-selector.SearchCommands
---@field store fun(settings?: venv-selector.Settings): venv-selector.Settings
---@field get_user_options fun(): venv-selector.Options
---@field get_user_settings fun(): venv-selector.Settings
---@field get_defaults fun(): venv-selector.Settings


return M
