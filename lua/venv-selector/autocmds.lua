-- lua/venv-selector/autocmds.lua

require("venv-selector.types")

local M = {}

function M.create()
    -- ============================================================
    -- Cached venv initial restore (one-shot per buffer)
    -- ============================================================

    ---Return true if the buffer is a normal on-disk python buffer (not a special buftype).
    ---@param bufnr integer
    ---@return boolean ok
    local function is_normal_python_buf(bufnr)
        return vim.api.nvim_buf_is_valid(bufnr)
            and vim.bo[bufnr].buftype == ""
            and vim.bo[bufnr].filetype == "python"
    end

    local group_cache = vim.api.nvim_create_augroup("VenvSelectorCachedVenv", { clear = true })

    vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "FileType" }, {
        group = group_cache,
        callback = function(args)
            ---@cast args venv-selector.AutocmdArgs
            local bufnr = args.buf
            if not is_normal_python_buf(bufnr) then
                return
            end

            -- Skip uv buffers
            local uv2 = require("venv-selector.uv2")
            if uv2.is_uv_buffer(bufnr) then
                return
            end

            -- one-shot per buffer
            if vim.b[bufnr].venv_selector_cache_checked then
                return
            end
            vim.b[bufnr].venv_selector_cache_checked = true

            -- If this project is already active globally, do not trigger a cache restore.
            local pr = require("venv-selector.project_root").key_for_buf(bufnr)
            local venv = require("venv-selector.venv")
            if pr and type(venv.active_project_root) == "function" and venv.active_project_root() == pr then
                require("venv-selector.logger").debug(
                    ("cache-autocmd skip (project already active) b=%d root=%s"):format(bufnr, pr)
                )
                return
            end

            require("venv-selector.logger").debug(
                ("cache-autocmd once b=%d file=%s"):format(bufnr, vim.api.nvim_buf_get_name(bufnr))
            )

            -- Defer: allow project root detection / session restore / filetype to settle
            vim.defer_fn(function()
                if vim.api.nvim_buf_is_valid(bufnr) then
                    require("venv-selector.cached_venv").retrieve(bufnr)
                end
            end, 1000)
        end,
    })

    -- ============================================================
    -- Buffer-enter restoration + uv handling
    -- ============================================================

    local uv_group = vim.api.nvim_create_augroup("VenvSelectorUvDetect", { clear = true })

    ---Run the complete “restore/activate” flow for a python buffer, in priority order.
    ---This function is intentionally used by multiple autocmds to cover session restore and late filetype.
    ---
    ---@param bufnr integer
    ---@param reason venv-selector.ActivationReason
    local function uv_maybe_activate(bufnr, reason)
        if not is_normal_python_buf(bufnr) then
            return
        end

        local log = require("venv-selector.logger")
        log.debug(("uv-autocmd %s b=%d file=%s"):format(reason, bufnr, vim.api.nvim_buf_get_name(bufnr)))

        local cached = require("venv-selector.cached_venv")
        local uv2 = require("venv-selector.uv2")

        -- 1) session-local per-buffer restore (works even if persistent cache is disabled)
        cached.ensure_buffer_last_venv_activated(bufnr)

        -- 2) persistent cache restore (no-op if cache disabled)
        cached.ensure_cached_venv_activated(bufnr)

        -- 3) uv restore (PEP 723)
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

    -- Critical: catches session restore, already-loaded buffers, and window switches
    vim.api.nvim_create_autocmd("BufEnter", {
        group = uv_group,
        callback = function(args)
            ---@cast args venv-selector.AutocmdArgs
            uv_maybe_activate(args.buf, "enter")
        end,
    })

    -- When user edits metadata, re-run uv flow
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = uv_group,
        callback = function(args)
            ---@cast args venv-selector.AutocmdArgs
            local bufnr = args.buf
            if not is_normal_python_buf(bufnr) then
                return
            end
            require("venv-selector.uv2").run_uv_flow_if_needed(bufnr)
        end,
    })
end

return M
