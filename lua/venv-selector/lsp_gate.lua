local log              = require("venv-selector.logger")

-- Global timings (same for all servers)
local POLL_INTERVAL_MS  = 60
local MAX_TRIES         = 50
local START_GRACE_MS    = 250
local FORCE_EXTRA_TRIES = 80 -- ~4.8s extra after force stop

local M                = {}

local uv               = vim.uv or vim.loop

-- Per server-name gate (pyright, pylsp, etc.)
local st               = {
    gen = {},      -- name -> int
    inflight = {}, -- name -> bool
    pending = {},  -- name -> { cfg=table, bufs=table<number,true> }
    timer = {},    -- name -> uv_timer
}

local function bump(name)
    st.gen[name] = (st.gen[name] or 0) + 1
    return st.gen[name]
end

local function stop_all_by_name(name)
    for _, c in ipairs(vim.lsp.get_clients({ name = name })) do
        pcall(function() c:stop() end)
    end
end

local function any_alive(name)
    return #vim.lsp.get_clients({ name = name }) > 0
end

local function attach_all(bufs, new_id)
    for b, _ in pairs(bufs) do
        if vim.api.nvim_buf_is_valid(b) then
            pcall(vim.lsp.buf_attach_client, b, new_id)
        end
    end
end

local function first_valid_buf(bufs)
    for b, _ in pairs(bufs) do
        if vim.api.nvim_buf_is_valid(b) then return b end
    end
end

local function close_timer(name)
    local t = st.timer[name]
    if t then
        t:stop()
        t:close()
        st.timer[name] = nil
    end
end

-- inside lua/venv-selector/lsp_restart_gate.lua

local function schedule_poll(name, my_gen)
    close_timer(name)


    local function alive_count()
        return #vim.lsp.get_clients({ name = name })
    end

    local function stop_all(force)
        for _, c in ipairs(vim.lsp.get_clients({ name = name })) do
            pcall(function()
                -- Neovim 0.11: client:stop() supports a force boolean in practice across releases;
                -- pcall makes this safe even if the signature differs.
                c:stop(force)
            end)
        end
    end

    local t = uv.new_timer()
    st.timer[name] = t

    local tries = 0
    local forced = false

    t:start(POLL_INTERVAL_MS, POLL_INTERVAL_MS, vim.schedule_wrap(function()
        tries = tries + 1

        local alive = alive_count()
        log.debug(("gate.poll name=%s gen=%d tries=%d alive=%d forced=%s"):format(
            name, my_gen, tries, alive, tostring(forced)
        ))

        -- Stale request: a newer generation replaced this one
        if st.gen[name] ~= my_gen then
            close_timer(name)
            st.inflight[name] = false
            return
        end

        -- Normal wait: let old client(s) exit gracefully
        if alive > 0 and tries < MAX_TRIES then
            return
        end

        -- Timeout reached and still alive: force-stop once, then keep waiting
        if alive > 0 and not forced then
            log.debug(("gate.force_stop name=%s gen=%d alive=%d"):format(name, my_gen, alive))
            forced = true
            tries = 0
            stop_all(true)
            return
        end

        -- After force-stop window, if still alive: abort to avoid duplicate servers
        if alive > 0 and forced and tries < FORCE_EXTRA_TRIES then
            return
        end
        if alive > 0 and forced then
            log.debug(("gate.abort name=%s gen=%d reason=still_alive_after_force alive=%d"):format(
                name, my_gen, alive
            ))
            close_timer(name)
            st.pending[name] = nil
            st.inflight[name] = false
            return
        end

        -- Now alive == 0 -> proceed to start
        close_timer(name)

        local job = st.pending[name]
        st.pending[name] = nil
        if not job or not job.cfg or not job.bufs then
            log.debug(("gate.start aborted name=%s gen=%d reason=no_job"):format(name, my_gen))
            st.inflight[name] = false
            return
        end

        local first_buf = first_valid_buf(job.bufs)
        log.debug(("gate.start name=%s gen=%d first_buf=%s"):format(name, my_gen, tostring(first_buf)))
        if not first_buf then
            log.debug(("gate.start aborted name=%s gen=%d reason=no_valid_buf"):format(name, my_gen))
            st.inflight[name] = false
            return
        end
        log.debug(("gate.start bufname=%s"):format(vim.api.nvim_buf_get_name(first_buf)))

        local function do_start()
            if st.gen[name] ~= my_gen then
                st.inflight[name] = false
                return
            end

            local new_id = vim.lsp.start(job.cfg, {
                bufnr = first_buf,
                reuse_client = function() return false end,
            })

            log.debug(("gate.started name=%s gen=%d new_id=%s"):format(name, my_gen, tostring(new_id)))

            if new_id then
                for b, _ in pairs(job.bufs) do
                    if b ~= first_buf and vim.api.nvim_buf_is_valid(b) then
                        pcall(vim.lsp.buf_attach_client, b, new_id)
                    end
                end

                vim.defer_fn(function()
                    local c = vim.lsp.get_client_by_id(new_id)
                    if not c then
                        log.debug(("gate.verify name=%s gen=%d new_id=%d missing_after_start"):format(name, my_gen,
                            new_id))
                        return
                    end
                    local attached = false
                    for b, _ in pairs(c.attached_buffers or {}) do
                        if b == first_buf then
                            attached = true; break
                        end
                    end
                    log.debug(("gate.verify name=%s gen=%d new_id=%d attached_to_first_buf=%s"):format(
                        name, my_gen, new_id, tostring(attached)
                    ))
                end, 600)
            end

            st.inflight[name] = false

            if st.pending[name] then
                M.request(name, st.pending[name].cfg, st.pending[name].bufs)
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
function M.request(name, cfg, bufs)
    local my_gen = bump(name)

    local nbuf = 0
    for _ in pairs(bufs or {}) do nbuf = nbuf + 1 end
    log.debug(("gate.request name=%s gen=%d inflight=%s bufs=%d"):format(
        name, my_gen, tostring(st.inflight[name] == true), nbuf
    ))


    st.pending[name] = { cfg = cfg, bufs = bufs }

    if st.inflight[name] then
        return
    end
    st.inflight[name] = true

    stop_all_by_name(name)
    schedule_poll(name, my_gen)
end

return M
