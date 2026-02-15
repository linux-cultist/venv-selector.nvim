-- lua/venv-selector/types.lua
--
-- Shared type definitions for venv-selector.nvim.
-- This file is intentionally "require-able" so other modules can pull in annotations
-- without duplicating type blocks everywhere.

local M = {}

---@class venv-selector.API
---@field venv fun(): string|nil
---@field python fun(): string|nil
---@field source fun(): string|nil

---@class venv-selector.SearchResult
---@field path string The file path to the python executable (selected env interpreter)
---@field name string Display name of the environment/interpreter
---@field icon? string Icon to display (picker UI)
---@field type string Type of environment (e.g., "venv", "conda", "uv")
---@field source string Search source that found this result (e.g., "cwd", "workspace", ...)

---@class venv-selector.SearchCallbacks
---@field on_result fun(result: venv-selector.SearchResult) Called for each result found
---@field on_complete fun() Called when search completes

---@class venv-selector.Picker
---@field insert_result fun(self: venv-selector.Picker, result: venv-selector.SearchResult) Add a result to the picker
---@field search_done fun(self: venv-selector.Picker) Called when search completes

---@class venv-selector.ActiveJobState: venv-selector.SearchConfig
---@field name string Search name (e.g. "cwd", "workspace")
---@field type? string Env type for results from this job
---@field execute_command? string Final command executed
---@field on_telescope_result_callback? fun(line: string, source: string): string
---@field on_fd_result_callback? fun(line: string, source: string): string
---@field stderr_output? string[]

---@class venv-selector.SnacksItem: venv-selector.SearchResult
---@field text string

---@class venv-selector.SnacksPickerState: venv-selector.Picker
---@field results venv-selector.SnacksItem[] Accumulated items for Snacks
---@field picker any|nil Active Snacks picker instance
---@field _refresh_scheduled boolean True while a refresh timer is pending
---@field _closed boolean True after on_close has fired (prevents further refresh)

---@class venv-selector.NativePickerState: venv-selector.Picker
---@field results venv-selector.SearchResult[] Accumulated entries

---@class venv-selector.MiniPickState: venv-selector.Picker
---@field results venv-selector.MiniPickItem[]
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

---@alias venv-selector.VenvType "venv"|"anaconda"|"uv"
---@alias venv-selector.Hook fun(python_path: string|nil, env_type: venv-selector.VenvType|nil, bufnr: integer|nil): integer|nil

---@class venv-selector.CachedVenvInfo
---@field value string Absolute path to python executable
---@field type venv-selector.VenvType Environment type
---@field source? string Source tag used by venv-selector (e.g. "workspace", "cwd", ...)

---@alias venv-selector.CachedVenvTable table<string, venv-selector.CachedVenvInfo>


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
---@field log_level? venv-selector.LogLevel
---@field debug? boolean|venv-selector.LogLevel  -- backward compatible
---@field fd_binary_name? string
---@field require_lsp_activation boolean
---@field shell? table
---@field on_telescope_result_callback? fun(filename: string): string
---@field picker_filter_type "substring"|"character"
---@field selected_venv_marker_color string
---@field selected_venv_marker_icon string
---@field picker_icons table<string, string>
---@field picker_columns string[]
---@field picker venv-selector.PickerName
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

---@alias venv-selector.PickerName
---| "telescope"
---| "fzf-lua"
---| "snacks"
---| "mini-pick"
---| "native"
---| "auto"

---@alias venv-selector.PickerSetting venv-selector.PickerName

---@class venv-selector.GuiOpenOpts: venv-selector.SearchOpts
---@field icon? string Optional icon override (passed through to search layer)
---@field on_telescope_result_callback? fun(line: string, source: string): string
---@field on_fd_result_callback? fun(line: string, source: string): string

---@class venv-selector.PickerSpec
---@field name venv-selector.PickerName
---@field module? string Module to require to consider it installed; nil means always available


---@class venv-selector.LspCmdEnv
---@field cmd_env table<string, string>

---@class venv-selector.LspClientConfig
---@field settings? table
---@field cmd_env? table<string, string>
---@field capabilities? table
---@field handlers? table
---@field on_attach? fun(...)
---@field init_options? table

---@class venv-selector.RestartMemo
---@field py string
---@field ty string


---@class venv-selector.AutocmdArgs
---@field buf integer

---@class venv-selector.InitModule
---@field setup fun(conf?: venv-selector.Settings)
---@field python fun(): string|nil
---@field venv fun(): string|nil
---@field source fun(): string|nil
---@field workspace_paths fun(): string[]
---@field cwd fun(): string
---@field file_dir fun(): string|nil
---@field stop_lsp_servers fun()
---@field activate_from_path fun(python_path: string)
---@field deactivate fun()

---@alias venv-selector.ActivationReason "read"|"filetype"|"enter"

---@alias venv-selector.LogLevel "TRACE"|"DEBUG"|"INFO"|"WARNING"|"ERROR"|"NONE"



---@class venv-selector.LspBufSet
---@field [integer] true

---@class venv-selector.LspGateJob
---@field cfg table
---@field bufs venv-selector.LspBufSet

---@class venv-selector.LspGateState
---@field gen table<string, integer>
---@field inflight table<string, boolean>
---@field pending table<string, venv-selector.LspGateJob|nil>
---@field timer table<string, venv-selector.UvTimerHandle|nil>

---@class venv-selector.SearchConfig
---@field command string
---@field type? venv-selector.VenvType|string
---@field execute_command? string
---@field on_telescope_result_callback? fun(line: string, source: string): string
---@field on_fd_result_callback? fun(line: string, source: string): string
---@field stderr_output? string[]

---@class venv-selector.SearchOpts
---@field args? string
---@field icon? string
---@field on_telescope_result_callback? fun(line: string, source: string): string
---@field on_fd_result_callback? fun(line: string, source: string): string

---@class venv-selector.SearchModule
---@field active_jobs table<integer, venv-selector.ActiveJobState>

---@class venv-selector.MiniPickItem: venv-selector.SearchResult
---@field text string


---@alias venv-selector.UserCommandOpts vim.api.keyset.user_command

---@alias venv-selector.UvTimerHandle uv.uv_timer_t


---@class venv-selector.SystemResult
---@field code integer
---@field signal integer?
---@field stdout string?
---@field stderr string?



---@class venv-selector.VenvActivateOpts
---@field save_cache? boolean
---@field check_lsp? boolean




---@class venv-selector.WorkspaceFolder
---@field name? string
---@field uri? string

---@class venv-selector.TelescopeEntry : venv-selector.SearchResult
---@field value any
---@field ordinal string
---@field display fun(e: venv-selector.TelescopeEntry): any


return M
