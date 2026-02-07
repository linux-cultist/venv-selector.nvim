local log               = require("venv-selector.logger")

-- Global timings (same for all servers)
local POLL_INTERVAL_MS  = 60
local MAX_TRIES         = 3
local START_GRACE_MS    = 250
local FORCE_EXTRA_TRIES = 30

local M                 = {}

local uv                = vim.uv or vim.loop

local function split_key(key)
    if type(key) ~= "string" or key == "" then
        return nil, nil
    end
    local name, root = key:match("^(.-)::(.*)$")
    if not name then
        -- allow old "name" keys; treat as no-root
        return key, ""
    end
    return name, root
end

local function clients_for_key(key)
    local name, root = split_key(key)
    if not name then return {} end
    local out = {}
    for _, c in ipairs(vim.lsp.get_clients({ name = name })) do
        if root == "" then
            out[#out + 1] = c
        else
            local r = (c.config and c.config.root_dir) or ""
            if r == root then
                out[#out + 1] = c
            end
        end
    end
    return out
end

-- Per server-name gate (pyright, pylsp, etc.)
local st = {
    gen = {},      -- name -> int
    inflight = {}, -- name -> bool
    pending = {},  -- name -> { cfg=table, bufs=table<number,true> }
    timer = {},    -- name -> uv_timer
}

local function bump(key)
    st.gen[key] = (st.gen[key] or 0) + 1
    return st.gen[key]
end



local function first_valid_buf(bufs)
    for b, _ in pairs(bufs) do
        if vim.api.nvim_buf_is_valid(b) then return b end
    end
end

local function close_timer(key)
    local t = st.timer[key]
    if t then
        t:stop()
        t:close()
        st.timer[key] = nil
    end
end

local function stop_all_by_key(key, force)
    for _, c in ipairs(clients_for_key(key)) do
        pcall(function() c:stop(force) end)
    end
end

local function alive_count(key)
    return #clients_for_key(key)
end

-- inside lua/venv-selector/lsp_restart_gate.lua

local function schedule_poll(key, my_gen)
    if type(key) ~= "string" or key == "" then
        log.debug("gate.schedule_poll: nil/empty key; abort")
        return
    end

    close_timer(key)

    local t = uv.new_timer()
    st.timer[key] = t

    local tries = 0
    local forced = false

    t:start(POLL_INTERVAL_MS, POLL_INTERVAL_MS, vim.schedule_wrap(function()
        tries = tries + 1

        -- FIX: pass key
        local alive = alive_count(key)
        log.debug(("gate.poll key=%s gen=%d tries=%d alive=%d forced=%s"):format(
            key, my_gen, tries, alive, tostring(forced)
        ))

        if st.gen[key] ~= my_gen then
            close_timer(key)
            st.inflight[key] = false
            return
        end

        if alive > 0 and tries < MAX_TRIES then
            return
        end

        if alive > 0 and not forced then
            log.debug(("gate.force_stop key=%s gen=%d alive=%d"):format(key, my_gen, alive))
            forced = true
            tries = 0
            -- FIX: correct function
            stop_all_by_key(key, true)
            return
        end

        if alive > 0 and forced and tries < FORCE_EXTRA_TRIES then
            return
        end
        if alive > 0 and forced then
            log.debug(("gate.abort key=%s gen=%d reason=still_alive_after_force alive=%d"):format(
                key, my_gen, alive
            ))
            close_timer(key)
            st.pending[key] = nil
            st.inflight[key] = false
            return
        end

        close_timer(key)

        local job = st.pending[key]
        st.pending[key] = nil
        if not job or not job.cfg or not job.bufs then
            log.debug(("gate.start aborted key=%s gen=%d reason=no_job"):format(key, my_gen))
            st.inflight[key] = false
            return
        end

        local first_buf = first_valid_buf(job.bufs)
        log.debug(("gate.start key=%s gen=%d first_buf=%s"):format(key, my_gen, tostring(first_buf)))
        if not first_buf then
            log.debug(("gate.start aborted key=%s gen=%d reason=no_valid_buf"):format(key, my_gen))
            st.inflight[key] = false
            return
        end
        log.debug(("gate.start bufname=%s"):format(vim.api.nvim_buf_get_name(first_buf)))

        local function do_start()
            if st.gen[key] ~= my_gen then
                st.inflight[key] = false
                return
            end

            local new_id = vim.lsp.start(job.cfg, {
                bufnr = first_buf,
                reuse_client = function() return false end,
            })

            log.debug(("gate.started key=%s gen=%d new_id=%s"):format(key, my_gen, tostring(new_id)))

            if new_id then
                for b, _ in pairs(job.bufs) do
                    if b ~= first_buf and vim.api.nvim_buf_is_valid(b) then
                        pcall(vim.lsp.buf_attach_client, b, new_id)
                    end
                end
            end

            st.inflight[key] = false

            if st.pending[key] then
                M.request(key, st.pending[key].cfg, st.pending[key].bufs)
            end
        end

        if START_GRACE_MS > 0 then
            vim.defer_fn(do_start, START_GRACE_MS)
        else
            do_start()
        end
    end))
end

--- Request restart for a server name with a fully-built cfg and buffer set.
--- Coalesces multiple requests; guarantees a new client is started.
function M.request(key, cfg, bufs)
    if type(key) ~= "string" or key == "" then
        log.debug("gate.request: nil/empty key; ignoring")
        return
    end

    local my_gen = bump(key)

    st.pending[key] = { cfg = cfg, bufs = bufs }

    if st.inflight[key] then return end
    st.inflight[key] = true

    stop_all_by_key(key, false)
    schedule_poll(key, my_gen)
end

return M
