-- lua/venv-selector/lsp_gate.lua
--
-- LSP restart gate:
-- Coalesces repeated restart requests per logical key (typically "client_name::root_dir")
-- and guarantees a *fresh* client is started after the previous one has stopped.
--
-- Why this exists:
-- - venv activation can happen frequently (BufEnter, cache restore, uv flow).
-- - Many LSP servers do not reliably reload pythonPath/cmd_env without a restart.
-- - Naive restart loops can race: stop/start overlapping, duplicate clients, or stale restarts.
--
-- Gate behavior:
-- - Each request replaces the pending job for that key.
-- - A generation counter (st.gen[key]) invalidates older polls/starts.
-- - We stop existing clients, poll for them to exit, optionally force-stop, then start a new one.
-- - Buffers previously attached to the old client are re-attached to the new client.

local log               = require("venv-selector.logger")

-- Global timings (same for all keys/servers).
-- POLL_INTERVAL_MS: how often we check whether old clients are gone.
-- MAX_TRIES: number of polls we wait before escalating to force-stop.
-- START_GRACE_MS: small delay before starting a new client after the old one is gone.
-- FORCE_EXTRA_TRIES: number of polls we allow after force-stop before aborting.
local POLL_INTERVAL_MS  = 60
local MAX_TRIES         = 3
local START_GRACE_MS    = 250
local FORCE_EXTRA_TRIES = 30

local M                 = {}

local uv                = vim.uv


---Per-key gate state (the "key" is usually "name::root").
---@type venv-selector.LspGateState
local st = {
    gen = {},
    inflight = {},
    pending = {},
    timer = {},
}

---Split a gate key into (client_name, root_dir).
---Supports legacy keys without "::" by treating them as (name, "").
---
---@param key string|nil
---@return string|nil name LSP client name (e.g. "pyright")
---@return string|nil root Root directory scope; "" means "any root"
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

---Return all currently running LSP clients matching the provided gate key.
---If key has root=="", returns all clients with that name (any root).
---
---@param key string
---@return any[] clients
local function clients_for_key(key)
    local name, root = split_key(key)
    if not name then
        return {}
    end

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

---Increment generation for this key.
---Any in-flight poll/start loops holding an older generation should abort.
---
---@param key string
---@return integer gen New generation value
local function bump(key)
    st.gen[key] = (st.gen[key] or 0) + 1
    return st.gen[key]
end

---Pick any valid buffer from a buffer-set.
---Used to seed vim.lsp.start; remaining buffers are attached afterwards.
---
---@param bufs venv-selector.LspBufSet
---@return integer|nil bufnr
local function first_valid_buf(bufs)
    for b, _ in pairs(bufs) do
        if vim.api.nvim_buf_is_valid(b) then
            return b
        end
    end
    return nil
end

---Stop and close the poll timer for this key (if any).
---
---@param key string
local function close_timer(key)
    local t = st.timer[key]
    if t then
        t:stop()
        t:close()
        st.timer[key] = nil
    end
end

---Stop all LSP clients matching this key.
---`force=true` requests a force-stop (implementation-dependent per client).
---
---@param key string
---@param force boolean
local function stop_all_by_key(key, force)
    for _, c in ipairs(clients_for_key(key)) do
        -- Some clients may error on stop; do not let one failure break the loop.
        pcall(function()
            c:stop(force)
        end)
    end
end

---Return count of currently alive clients for this key.
---
---@param key string
---@return integer
local function alive_count(key)
    return #clients_for_key(key)
end

---Poll loop that waits for all old clients (for this key) to stop, then starts a new one.
---Older generations abort early.
---
---@param key string
---@param my_gen integer Generation captured when the restart was requested
local function schedule_poll(key, my_gen)
    if type(key) ~= "string" or key == "" then
        log.debug("gate.schedule_poll: nil/empty key; abort")
        return
    end

    -- Ensure only one timer exists per key.
    close_timer(key)

    local t = uv.new_timer()
    st.timer[key] = t

    local tries = 0
    local forced = false

    t:start(POLL_INTERVAL_MS, POLL_INTERVAL_MS, vim.schedule_wrap(function()
        tries = tries + 1

        local alive = alive_count(key)
        log.debug(("gate.poll key=%s gen=%d tries=%d alive=%d forced=%s"):format(
            key, my_gen, tries, alive, tostring(forced)
        ))

        -- If a newer request came in, abort this run.
        if st.gen[key] ~= my_gen then
            close_timer(key)
            st.inflight[key] = false
            return
        end

        -- Wait a few ticks for normal shutdown.
        if alive > 0 and tries < MAX_TRIES then
            return
        end

        -- Escalate: force-stop once.
        if alive > 0 and not forced then
            log.debug(("gate.force_stop key=%s gen=%d alive=%d"):format(key, my_gen, alive))
            forced = true
            tries = 0
            stop_all_by_key(key, true)
            return
        end

        -- After forcing, give extra time before giving up.
        if alive > 0 and forced and tries < FORCE_EXTRA_TRIES then
            return
        end

        -- Still alive after force-stop grace period: abort (do not start a new client).
        if alive > 0 and forced then
            log.debug(("gate.abort key=%s gen=%d reason=still_alive_after_force alive=%d"):format(
                key, my_gen, alive
            ))
            close_timer(key)
            st.pending[key] = nil
            st.inflight[key] = false
            return
        end

        -- Old clients are gone: proceed to start.
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

        ---Start a new LSP client for this key and attach buffers.
        local function do_start()
            -- Abort if a newer generation has superseded this start.
            if st.gen[key] ~= my_gen then
                st.inflight[key] = false
                return
            end

            -- Always start a fresh client; never reuse an existing one.
            local new_id = vim.lsp.start(job.cfg, {
                bufnr = first_buf,
                reuse_client = function()
                    return false
                end,
            })

            log.debug(("gate.started key=%s gen=%d new_id=%s"):format(key, my_gen, tostring(new_id)))

            -- Attach all remaining buffers to the newly started client.
            if new_id then
                for b, _ in pairs(job.bufs) do
                    if b ~= first_buf and vim.api.nvim_buf_is_valid(b) then
                        pcall(vim.lsp.buf_attach_client, b, new_id)
                    end
                end
            end

            st.inflight[key] = false

            -- If another request arrived while starting, run it next.
            if st.pending[key] then
                M.request(key, st.pending[key].cfg, st.pending[key].bufs)
            end
        end

        -- Small grace delay helps avoid flapping when clients take a moment to fully detach.
        if START_GRACE_MS > 0 then
            vim.defer_fn(do_start, START_GRACE_MS)
        else
            do_start()
        end
    end))
end

---Request a restart for the given key with a fully-built client config and buffer set.
---Coalesces multiple requests:
---- Only the latest (cfg, bufs) is retained.
---- At most one stop/poll/start cycle runs at a time per key.
---Guarantees a fresh client is started (reuse_client always returns false).
---
---@param key string Gate key, typically "client_name::root_dir"
---@param cfg table LSP client config passed to vim.lsp.start
---@param bufs venv-selector.LspBufSet Set of buffers that should attach to the started client
function M.request(key, cfg, bufs)
    if type(key) ~= "string" or key == "" then
        log.debug("gate.request: nil/empty key; ignoring")
        return
    end

    local my_gen = bump(key)

    ---@type venv-selector.LspGateJob
    st.pending[key] = { cfg = cfg, bufs = bufs }

    -- If a cycle is already running, this request is now pending and will be picked up later.
    if st.inflight[key] then
        return
    end

    st.inflight[key] = true

    -- Begin by asking existing clients to stop gracefully; polling will follow.
    stop_all_by_key(key, false)
    schedule_poll(key, my_gen)
end

---@cast M venv-selector.LspGateModule
return M
