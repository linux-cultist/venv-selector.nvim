local M = {}

-- vim.api.nvim_create_autocmd("BufEnter", {
--     group = group,
--     callback = function(args)
--         vim.schedule(function()
--             local uv = require("venv-selector.uv2")
--             uv.ensure_uv_buffer_activated(args.buf)
--         end)
--     end,
-- })

-- vim.api.nvim_create_autocmd("BufWritePost", {
--     group = group,
--     callback = function(args)
--         vim.schedule(function()
--             local uv = require("venv-selector.uv2")
--             uv.run_uv_flow_if_needed(args.buf)
--         end)
--     end,
-- })

local group = vim.api.nvim_create_augroup("VenvSelectorUvDetect", { clear = true })

local dbg_group = vim.api.nvim_create_augroup("VenvSelectorBufDebugLog", { clear = true })

local function log_buf(event, bufnr)
    local ok, log = pcall(require, "venv-selector.logger")
    if not ok then return end

    local ok2, path_mod = pcall(require, "venv-selector.path")
    if not ok2 then return end

    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    if vim.bo[bufnr].buftype ~= "" then return end

    local file = vim.api.nvim_buf_get_name(bufnr)
    local ft = vim.bo[bufnr].filetype
    local global_py = path_mod.current_python_path or "nil"
    local uv_cached = vim.b[bufnr].venv_selector_uv_last_python or "nil"

    log.debug(("%s b=%d ft=%s file=%s"):format(event, bufnr, tostring(ft), file))
    log.debug(("  global interpreter=%s"):format(global_py))
    log.debug(("  uv cached interpreter=%s"):format(uv_cached))
end

-- vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "WinEnter" }, {
--     group = dbg_group,
--     callback = function(args)
--         local ok, err = pcall(log_buf, args.event, args.buf)
--         if not ok then
--             pcall(function()
--                 require("venv-selector.logger").debug("buf debug autocmd error: " .. tostring(err))
--             end)
--         end
--     end,
-- })

local group_cache = vim.api.nvim_create_augroup("VenvSelectorCachedVenv", { clear = true })

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "FileType" }, {
    group = group_cache,
    callback = function(args)
        local bufnr = args.buf
        if not vim.api.nvim_buf_is_valid(bufnr) then return end
        if vim.bo[bufnr].buftype ~= "" then return end
        if vim.bo[bufnr].filetype ~= "python" then return end

        local uv2 = require("venv-selector.uv2")
        if uv2.is_uv_buffer(bufnr) then
            return
        end

        if vim.b[bufnr].venv_selector_cache_checked then
            return
        end
        vim.b[bufnr].venv_selector_cache_checked = true


        local pr = require("venv-selector.project_root").key_for_buf(bufnr)
        local venv = require("venv-selector.venv")

        if pr and venv.active_project_root and venv.active_project_root() == pr then
            require("venv-selector.logger").debug(
                ("cache-autocmd skip (project already active) b=%d root=%s"):format(bufnr, pr)
            )
            return
        end

        require("venv-selector.logger").debug(
            ("cache-autocmd once b=%d file=%s"):format(bufnr, vim.api.nvim_buf_get_name(bufnr))
        )

        vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(bufnr) then
                require("venv-selector.cached_venv").retrieve(bufnr)
            end
        end, 1000)
    end,
})

-- vim.api.nvim_create_autocmd({ "BufReadPost", "FileType" }, {
--     group = group,
--     callback = function(args)
--         if vim.bo[args.buf].buftype ~= "" then return end
--         if vim.bo[args.buf].filetype ~= "python" then return end
--         if require("venv-selector.uv2").is_uv_buffer(args.buf) then return end

--         -- Old cached venv behavior: cwd-keyed, activates via venv.activate()
--         -- Delay to allow lspconfig autostart to attach at least one python client.
--         -- Use vim.defer_fn (milliseconds).
--         vim.defer_fn(function()
--             -- buffer might have changed; still apply globally as before
--             require("venv-selector.cached_venv").retrieve()
--         end, 1000)
--     end,
-- })

-- 1) When a python buffer is first read or created
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = group,
    callback = function(args)
        if vim.bo[args.buf].filetype ~= "python" then return end
        require("venv-selector.uv2").ensure_uv_buffer_activated(args.buf)
    end,
})

-- 2) In case filetype is set later by another plugin
vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "python",
    callback = function(args)
        require("venv-selector.uv2").ensure_uv_buffer_activated(args.buf)
    end,
})

-- 3) When user edits PEP-723 metadata
vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(args)
        if vim.bo[args.buf].filetype ~= "python" then return end
        require("venv-selector.uv2").run_uv_flow_if_needed(args.buf)
    end,
})

-- vim.api.nvim_create_autocmd("BufEnter", {
--     group = vim.api.nvim_create_augroup("VenvSelectorUvBufEnter", { clear = true }),
--     callback = function(args)
--         if vim.bo[args.buf].filetype ~= "python" then return end
--         require("venv-selector.uv2").ensure_uv_buffer_activated(args.buf)
--     end,
-- })

-- vim.api.nvim_create_autocmd("LspAttach", {
--   group = group,
--   callback = function(args)
--     require("venv-selector.lsp_gate").on_lsp_attach(args)
--   end,
-- })

-- vim.api.nvim_create_autocmd("LspDetach", {
--   group = group,
--   callback = function(args)
--     require("venv-selector.lsp_gate").on_lsp_detach(args)
--   end,
-- })

-- vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "FileType" }, {
--   group = group,
--   callback = function(args)
--     if vim.bo[args.buf].filetype ~= "python" then return end
--     require("venv-selector.uv2").ensure_uv_buffer_activated(args.buf)
--   end,
-- })

-- vim.api.nvim_create_autocmd("BufWritePost", {
--   group = group,
--   callback = function(args)
--     if vim.bo[args.buf].filetype ~= "python" then return end
--     require("venv-selector.uv2").run_uv_flow_if_needed(args.buf)
--   end,
-- })



function M.python()
    return require("venv-selector.path").current_python_path
end

function M.venv()
    return require("venv-selector.path").current_venv_path
end

function M.source()
    return require("venv-selector.path").current_source
end

function M.workspace_paths()
    return require("venv-selector.workspace").list_folders()
end

function M.cwd()
    return vim.fn.getcwd()
end

function M.file_dir()
    return require("venv-selector.path").get_current_file_directory()
end

function M.stop_lsp_servers()
    require("venv-selector.venv").stop_lsp_servers()
end

function M.activate_from_path(python_path)
    require("venv-selector.venv").activate(python_path, "activate_from_path", true)
end

function M.deactivate()
    require("venv-selector.path").remove_current()
    require("venv-selector.venv").unset_env_variables()
end

---Initialize nvim-notify if available
local function setup_notify()
    local options = require("venv-selector.config").get_user_options()

    if options and options.override_notify then
        local has_notify, notify_plugin = pcall(require, "notify")
        if has_notify then
            vim.notify = notify_plugin
        end
    end
end

---Check if Neovim version meets minimum requirements
---@return boolean true if version is compatible, false otherwise
local function check_nvim_version()
    local version = vim.version()
    if version.major == 0 and version.minor < 11 then
        local error_msg = string.format(
            "venv-selector.nvim requires Neovim 0.11+. Current version: %d.%d.%d\n" ..
            "Please upgrade Neovim or remove venv-selector.nvim from your configuration.",
            version.major, version.minor, version.patch
        )
        vim.notify(error_msg, vim.log.levels.ERROR, { title = "VenvSelect" })
        return false
    end
    return true
end

---Enable debug logging if requested
---@param conf table|nil
local function setup_debug_logging(conf)
    if conf and conf.options and conf.options.debug then
        local log = require("venv-selector.logger")
        log.enabled = true
    end
end

---Setup highlight group for selected venv marker
local function setup_highlight()
    local options = require("venv-selector.config").get_user_options()
    vim.api.nvim_set_hl(0, "VenvSelectActiveVenv", {
        fg = options.selected_venv_marker_color
    })
end

local function valid_fd()
    local options = require("venv-selector.config").user_settings.options
    if options.fd_binary_name == nil then
        local message =
        "Cannot find any fd binary on your system. If its installed under a different name, you can set options.fd_binary_name to its name."
        require("venv-selector.logger").error(message)
        vim.notify(message, vim.log.levels.ERROR, { title = "VenvSelect" })
        return false
    end
    return true
end



---Setup plugin configuration, commands, and integrations
---@param conf venv-selector.Settings|nil User configuration
function M.setup(conf)
    if not check_nvim_version() or not valid_fd() then
        return
    end

    setup_debug_logging(conf)

    local config = require("venv-selector.config")
    config.store(conf)

    setup_notify()
    setup_highlight()

    require("venv-selector.user_commands").register()
end

return M
