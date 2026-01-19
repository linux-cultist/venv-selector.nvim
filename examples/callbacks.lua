-- Example callback utilities for venv-selector.nvim
-- Save this file in your Neovim config and require it from your plugin options.
--
-- Usage examples (adjust the module path to where you save this file):
--
-- opts = {
--   options = {
--     -- Global callback executed after a venv activates
--     on_venv_activate_callback = require("examples.callbacks").on_venv_activate_callback,
--
--     -- Global formatter for telescope results
--     on_telescope_result_callback = require("examples.callbacks").shorter_name,
--   },
--   search = {
--     -- Per-search callback (overrides global)
--     my_venvs = {
--       command = "fd /bin/python$ ~/Code --full-path",
--       on_telescope_result_callback = require("examples.callbacks").shorter_name,
--     },
--   },
-- }
--
-- Notes:
-- - This file is intentionally conservative: it uses pcall(require, ...) to avoid
--   hard failures if the plugin is not available at require-time.
-- - Adjust shell escaping and commands to your preferences when invoking shell tools.
-- - Place this under a module path that matches how you `require()` it (e.g. put it in
--   ~/.config/nvim/lua/examples/callbacks.lua and use require("examples.callbacks")).

local M = {}

-- Shorten long python interpreter paths for display in pickers.
-- Replaces the user's HOME with "~" and strips common python binary suffixes
-- so the picker shows the virtualenv directory instead of the full path.
function M.shorter_name(filename)
  if not filename or filename == "" then
    return filename
  end

  -- Replace home dir with ~ for readability
  local home = os.getenv("HOME") or ""
  if home ~= "" then
    filename = filename:gsub(home, "~")
  end

  -- Normalize Windows backslashes to slashes for easier pattern handling
  filename = filename:gsub("\\", "/")

  -- Remove common python binary suffixes
  -- Examples removed: /bin/python, /bin/python3, /bin/python3.10, /Scripts/python.exe
  filename = filename
               :gsub("/bin/python[%d%.]*$", "")    -- /bin/python, /bin/python3, /bin/python3.10
               :gsub("/Scripts/python%.exe$", "")  -- Windows scripts folder
               :gsub("/python%.exe$", "")          -- fallback windows pattern

  return filename
end

-- Helper: attempt to get the venv-selector API safely
local function get_venv_api()
  local ok, venv = pcall(require, "venv-selector")
  if not ok then
    return nil
  end
  return venv
end

-- Example: run a project-specific shell command after venv activation
-- This example:
--  - Listens for a venv activation (the callback is called when a venv activates)
--  - Registers an autocommand to run once when a terminal opens
--  - If the venv came from "poetry", it will run: `poetry env use <python_path>`
--
-- You can modify the logic to suit conda, pipx, uv, or other sources.
function M.on_venv_activate_callback()
  local venv = get_venv_api()
  if not venv then
    -- plugin not present; nothing to do
    return
  end

  -- Run only once per activation (guard inside the terminal callback)
  local command_run = false

  local function maybe_run()
    -- If already executed, do nothing
    if command_run then
      return
    end

    local source = venv.source()
    local python = venv.python()
    local venv_path = venv.venv()

    -- Example condition: only run for poetry-detected venvs
    if source == "poetry" and python and python ~= "" then
      -- Build a safe, escaped command for the shell.
      -- We use vim.fn.shellescape to avoid injection; the command will be fed into the terminal.
      local cmd = "poetry env use " .. vim.fn.shellescape(python) .. "\n"
      -- Feed the command so a freshly opened terminal receives it.
      -- Option: you might prefer to use jobs or vim.fn.system depending on your workflow.
      vim.api.nvim_feedkeys(cmd, "n", false)
      command_run = true
      return
    end

    -- Example: for conda/anaconda types, you might want to run `conda activate <env>`
    -- The plugin sets CONDA_PREFIX when appropriate; if you need special handling:
    if source == "anaconda" and venv_path and venv_path ~= "" then
      local env_name = vim.fn.fnamemodify(venv_path, ":t")
      if env_name and env_name ~= "" then
        local cmd = "conda activate " .. vim.fn.shellescape(env_name) .. "\n"
        vim.api.nvim_feedkeys(cmd, "n", false)
        command_run = true
        return
      end
    end

    -- Add other conditional handlers here as needed.
  end

  -- Create/replace a dedicated augroup so the autocmd can be updated safely
  vim.api.nvim_create_augroup("VenvSelector_OnActivate", { clear = true })

  -- Trigger when entering a terminal; the callback will run once thanks to command_run
  vim.api.nvim_create_autocmd("TermEnter", {
    group = "VenvSelector_OnActivate",
    pattern = "*",
    callback = maybe_run,
  })
end

-- Alternative example: display a short notification when a venv is activated.
-- Uses nvim-notify if available, otherwise falls back to vim.notify.
function M.notify_on_activate()
  local venv = get_venv_api()
  if not venv then
    return
  end

  local python = venv.python()
  local venv_path = venv.venv()
  local source = venv.source()

  if not venv_path or venv_path == "" then
    return
  end

  local name = vim.fn.fnamemodify(venv_path, ":t")
  local msg = ("Activated venv: %s (%s)"):format(name or "<unknown>", source or "unknown")

  -- prefer nvim-notify if present
  local ok, notify = pcall(require, "notify")
  if ok and notify then
    notify(msg, "info", { title = "Venv Selector" })
  else
    vim.notify(msg)
  end
end

-- Generic utility: run a user-supplied function once on terminal open after activation.
-- Example usage (in your plugin opts):
-- options = {
--   on_venv_activate_callback = function()
--     require("examples.callbacks").run_once_in_terminal(function(source, python, venv_path)
--       -- custom logic here
--     end)
--   end
-- }
function M.run_once_in_terminal(user_fn)
  if type(user_fn) ~= "function" then
    return
  end

  local venv = get_venv_api()
  if not venv then
    return
  end

  local called = false

  local function wrapper()
    if called then
      return
    end
    local ok, _ = pcall(user_fn, venv.source(), venv.python(), venv.venv())
    -- avoid propagating errors to user; just mark as called even if user_fn errors
    called = true
  end

  vim.api.nvim_create_augroup("VenvSelector_RunOnceUserFn", { clear = true })
  vim.api.nvim_create_autocmd("TermEnter", {
    group = "VenvSelector_RunOnceUserFn",
    pattern = "*",
    callback = wrapper,
  })
end

-- Return module
return M