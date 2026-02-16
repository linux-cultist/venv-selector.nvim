-- lua/venv-selector/lsp_gate.lua
--
-- LSP restart gate:
-- Coalesces repeated restart requests per logical key (typically "client_name::root_dir")
-- and guarantees a *fresh* client is started after the previous one has stopped.
--
-- Enhancement:
-- - Supports "rootless" LSP clients (root_dir=nil) by allowing a caller-provided
--   *scope* suffix in the key, and by avoiding collisions when root_dir is empty.

local log = require("venv-selector.logger")
local uv  = vim.uv

local POLL_INTERVAL_MS  = 60
local MAX_TRIES         = 3
local START_GRACE_MS    = 250
local FORCE_EXTRA_TRIES = 30

local M = {}

---@type venv-selector.LspGateState
local st = {
  gen = {},
  inflight = {},
  pending = {},
  timer = {},
}

-- ============================================================================
-- Key parsing + matching
-- ============================================================================

---Split a gate key into (client_name, scope).
---Key format: "name::scope"
---Legacy: "name" -> (name, "")
---
---@param key string|nil
---@return string|nil name
---@return string|nil scope
local function split_key(key)
  if type(key) ~= "string" or key == "" then
    return nil, nil
  end

  local name, scope = key:match("^(.-)::(.*)$")
  if not name then
    return key, ""
  end
  return name, scope
end

---Return a normalized root string for a client.
---Empty string means "rootless".
---
---@param c any
---@return string root
local function client_root(c)
  local r = (c and c.config and c.config.root_dir) or ""
  if type(r) ~= "string" then
    return ""
  end
  return r
end

---Return all currently running LSP clients matching the provided gate key.
---
---Matching rules:
---- If scope == "" (legacy): match by name only (any root). Not recommended, but preserved.
---- Else if scope starts with "root:" then match by exact root_dir (rootless does not match).
---- Else if scope starts with "scope:" then match *rootless* clients only (root_dir=="").
---  (This is how you avoid collisions when servers run with root_dir=nil.)
---
---@param key string
---@return any[] clients
local function clients_for_key(key)
  local name, scope = split_key(key)
  if not name then
    return {}
  end

  local want = scope or ""
  local out = {}

  for _, c in ipairs(vim.lsp.get_clients({ name = name })) do
    local r = client_root(c)

    if want == "" then
      out[#out + 1] = c
    elseif want:sub(1, 5) == "root:" then
      local root = want:sub(6)
      if r == root then
        out[#out + 1] = c
      end
    elseif want:sub(1, 6) == "scope:" then
      -- "rootless scope": only match clients that have no root_dir
      if r == "" then
        out[#out + 1] = c
      end
    else
      -- Back-compat: treat "name::/path" as "root:/path"
      if r == want then
        out[#out + 1] = c
      end
    end
  end

  return out
end

-- ============================================================================
-- Helpers
-- ============================================================================

---@param key string
---@return integer gen
local function bump(key)
  st.gen[key] = (st.gen[key] or 0) + 1
  return st.gen[key]
end

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

---@param key string
local function close_timer(key)
  local t = st.timer[key]
  if t then
    t:stop()
    t:close()
    st.timer[key] = nil
  end
end

---@param key string
---@param force boolean
local function stop_all_by_key(key, force)
  for _, c in ipairs(clients_for_key(key)) do
    pcall(function()
      c:stop(force)
    end)
  end
end

---@param key string
---@return integer
local function alive_count(key)
  return #clients_for_key(key)
end

-- ============================================================================
-- Poll / start cycle
-- ============================================================================

---@param key string
---@param my_gen integer
local function schedule_poll(key, my_gen)
  if type(key) ~= "string" or key == "" then
    log.trace("gate.schedule_poll: nil/empty key; abort")
    return
  end

  close_timer(key)

  local t = uv.new_timer()
  if not t then
    log.trace(("gate.schedule_poll: uv.new_timer() failed key=%s gen=%d"):format(key, my_gen))
    st.inflight[key] = false
    st.pending[key] = nil
    st.timer[key] = nil
    return
  end

  st.timer[key] = t

  local tries = 0
  local forced = false

  t:start(POLL_INTERVAL_MS, POLL_INTERVAL_MS, vim.schedule_wrap(function()
    tries = tries + 1

    local alive = alive_count(key)
    log.trace(("gate.poll key=%s gen=%d tries=%d alive=%d forced=%s"):format(
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
      stop_all_by_key(key, true)
      return
    end

    if alive > 0 and forced and tries < FORCE_EXTRA_TRIES then
      return
    end

    if alive > 0 and forced then
      log.trace(("gate.abort key=%s gen=%d reason=still_alive_after_force alive=%d"):format(
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
      log.trace(("gate.start aborted key=%s gen=%d reason=no_job"):format(key, my_gen))
      st.inflight[key] = false
      return
    end

    local first_buf = first_valid_buf(job.bufs)
    log.trace(("gate.start key=%s gen=%d first_buf=%s"):format(key, my_gen, tostring(first_buf)))

    if not first_buf then
      log.debug(("gate.start aborted key=%s gen=%d reason=no_valid_buf"):format(key, my_gen))
      st.inflight[key] = false
      return
    end

    log.trace(("gate.start bufname=%s"):format(vim.api.nvim_buf_get_name(first_buf)))

    local function do_start()
      if st.gen[key] ~= my_gen then
        st.inflight[key] = false
        return
      end

      local new_id = vim.lsp.start(job.cfg, {
        bufnr = first_buf,
        reuse_client = function()
          return false
        end,
      })

      log.debug(("LSP Started key=%s gen=%d new_id=%s"):format(key, my_gen, tostring(new_id)))

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

-- ============================================================================
-- Public API
-- ============================================================================

---Request a restart for the given key with a fully-built client config and buffer set.
---
---Key format recommendations:
---- Rooted (normal):   "ruff::root:/path/to/root"
---- Rootless (nil):    "ruff::scope:/path/or/buf:<n>"  (caller chooses stable scope)
---Legacy: "name" or "name::/path" still works.
---
---@param key string
---@param cfg table
---@param bufs venv-selector.LspBufSet
function M.request(key, cfg, bufs)
  if type(key) ~= "string" or key == "" then
    log.debug("gate.request: nil/empty key; ignoring")
    return
  end

  local my_gen = bump(key)

  ---@type venv-selector.LspGateJob
  st.pending[key] = { cfg = cfg, bufs = bufs }

  if st.inflight[key] then
    return
  end

  st.inflight[key] = true

  stop_all_by_key(key, false)
  schedule_poll(key, my_gen)
end

return M
