-- lua/venv-selector/autocmds.lua

require("venv-selector.types")

local M = {}

function M.create()
    ---@param bufnr integer
    ---@return boolean
    local function is_normal_python_buf(bufnr)
        return vim.api.nvim_buf_is_valid(bufnr)
            and vim.bo[bufnr].buftype == ""
            and vim.bo[bufnr].filetype == "python"
    end

    ---@param bufnr integer
    ---@return boolean
    local function is_disabled(bufnr)
        return vim.api.nvim_buf_is_valid(bufnr) and vim.b[bufnr].venv_selector_disabled == true
    end

    ---When entering a disabled python buffer, enforce "no active env" globally.
    ---This prevents a UV buffer's env from remaining active when returning to a deactivated buffer.
    ---@param bufnr integer
    local function enforce_deactivated_global_state(bufnr)
        -- Only enforce for real python buffers that are explicitly disabled.
        if not is_normal_python_buf(bufnr) then
            return
        end
        if not is_disabled(bufnr) then
            return
        end

        local venv = require("venv-selector.venv")
        local path = require("venv-selector.path")

        -- Clear plugin-owned global state (prevents "already active" too).
        -- Keep the disabled flag intact.
        venv.clear_active_state(bufnr)

        -- Ensure PATH/env is not left pointing at some other buffer's env (e.g. UV).
        path.remove_current()
        venv.unset_env_variables()
    end

    -- ============================================================
    -- Cached venv initial restore (one-shot per buffer)
    -- ============================================================

    local group_cache = vim.api.nvim_create_augroup("VenvSelectorCachedVenv", { clear = true })

    vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "FileType" }, {
        group = group_cache,
        callback = function(args)
            ---@cast args venv-selector.AutocmdArgs
            local bufnr = args.buf
            if not is_normal_python_buf(bufnr) then return end

            if is_disabled(bufnr) then
                enforce_deactivated_global_state(bufnr)
                return
            end

            local uv2 = require("venv-selector.uv2")
            if uv2.is_uv_buffer(bufnr) then return end

            if vim.b[bufnr].venv_selector_cache_checked then return end
            vim.b[bufnr].venv_selector_cache_checked = true

            local pr = require("venv-selector.project_root").key_for_buf(bufnr)
            local venv = require("venv-selector.venv")
            if pr and type(venv.active_project_root) == "function" and venv.active_project_root() == pr then
                return
            end

            vim.defer_fn(function()
                if not vim.api.nvim_buf_is_valid(bufnr) then return end
                if is_disabled(bufnr) then
                    enforce_deactivated_global_state(bufnr)
                    return
                end
                local cached_venv = require("venv-selector.cached_venv")
                if cached_venv.cache_auto_enabled() then
                    cached_venv.retrieve(bufnr)
                end
            end, 1000)
        end,
    })

    -- ============================================================
    -- Buffer-enter restoration + uv handling
    -- ============================================================

    local uv_group = vim.api.nvim_create_augroup("VenvSelectorUvDetect", { clear = true })

    ---@param bufnr integer
    ---@param reason venv-selector.ActivationReason
    local function uv_maybe_activate(bufnr, reason)
        if not is_normal_python_buf(bufnr) then return end

        -- If this buffer is disabled, actively enforce "no env" instead of just skipping restores.
        if is_disabled(bufnr) then
            enforce_deactivated_global_state(bufnr)
            return
        end

        local cached = require("venv-selector.cached_venv")
        local uv2 = require("venv-selector.uv2")

        cached.ensure_buffer_last_venv_activated(bufnr)
        cached.ensure_cached_venv_activated(bufnr)
        uv2.ensure_uv_buffer_activated(bufnr)
    end

    vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
        group = uv_group,
        callback = function(args)
            ---@cast args venv-selector.AutocmdArgs
            uv_maybe_activate(args.buf, "read")
        end,
    })

    vim.api.nvim_create_autocmd("FileType", {
        group = uv_group,
        pattern = "python",
        callback = function(args)
            ---@cast args venv-selector.AutocmdArgs
            uv_maybe_activate(args.buf, "filetype")
        end,
    })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = uv_group,
        callback = function(args)
            ---@cast args venv-selector.AutocmdArgs
            uv_maybe_activate(args.buf, "enter")
        end,
    })

    vim.api.nvim_create_autocmd("BufWritePost", {
        group = uv_group,
        callback = function(args)
            ---@cast args venv-selector.AutocmdArgs
            local bufnr = args.buf
            if not is_normal_python_buf(bufnr) then return end
            if is_disabled(bufnr) then
                -- Disabled buffer: do not run uv flow; keep it deactivated.
                enforce_deactivated_global_state(bufnr)
                return
            end
            require("venv-selector.uv2").run_uv_flow_if_needed(bufnr)
        end,
    })
end

return M
