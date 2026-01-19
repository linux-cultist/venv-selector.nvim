-- Examples for integrating venv-selector.nvim with statuslines and callbacks.
-- Save this file somewhere in your config (or copy relevant snippets into your
-- plugin options). Each function is safe to reference from the plugin `options`
-- table, for example `options.statusline_func.lualine = require("examples.statusline").lualine`.
--
-- Minimal usage with lazy.nvim (example):
-- {
--   "linux-cultist/venv-selector.nvim",
--   opts = {
--     options = {
--       statusline_func = {
--         lualine = require("examples.statusline").lualine,
--         nvchad  = require("examples.statusline").nvchad,
--       },
--       on_telescope_result_callback = require("examples.statusline").shorter_name,
--       on_venv_activate_callback = require("examples.statusline").on_venv_activate_callback,
--     },
--   },
-- }
--
-- Note: adjust the require path to match where you place this file in your config.

local M = {}

-- Shorten the path displayed in pickers:
-- - Replace the user's home directory with "~"
-- - Trim trailing "/bin/python" to show the virtualenv folder
function M.shorter_name(filename)
  if not filename or filename == "" then
    return filename
  end

  local home = os.getenv("HOME") or ""
  -- replace home with ~ if present
  if home ~= "" then
    filename = filename:gsub(home, "~")
  end
  -- remove common python binary suffixes
  filename = filename:gsub("/bin/python3?$", "")
  filename = filename:gsub("/bin/python3?%.exe$", "")
  return filename
end

-- Lualine integration: return a short string to show in lualine.
-- This function returns an empty string if no venv is active.
function M.lualine()
  local ok, venv_selector = pcall(require, "venv-selector")
  if not ok or not venv_selector then
    return ""
  end

  local venv_path = venv_selector.venv()
  if not venv_path or venv_path == "" then
    return ""
  end

  local venv_name = vim.fn.fnamemodify(venv_path, ":t")
  if not venv_name or venv_name == "" then
    return ""
  end

  -- You can customize the icon and formatting here.
  return "🐍 " .. venv_name .. " "
end

-- Nvchad integration: a similar renderer for nvchad's statusline module.
-- Return an empty string when no venv is active.
function M.nvchad()
  local ok, venv_selector = pcall(require, "venv-selector")
  if not ok or not venv_selector then
    return ""
  end

  local venv_path = venv_selector.venv()
  if not venv_path or venv_path == "" then
    return ""
  end

  local venv_name = vim.fn.fnamemodify(venv_path, ":t")
  if not venv_name or venv_name == "" then
    return ""
  end

  -- Example with a different icon and spacing for nvchad
  return " " .. venv_name .. " "
end

-- Example: run a command (like `poetry env use <python>`) after a venv is activated.
-- This example sets up an autocommand that runs once on the next terminal open.
-- The function uses the plugin API to figure out the source and python path.
-- You can assign this function to `options.on_venv_activate_callback`.
function M.on_venv_activate_callback()
  -- Make sure the plugin API is available when the callback runs.
  local ok, venv = pcall(require, "venv-selector")
  if not ok or not venv then
    return
  end

  local command_run = false

  local function run_shell_command()
    if command_run then
      return
    end

    local source = venv.source()
    local python = venv.python()

    -- Only run when the selected venv came from the "poetry" search.
    -- Modify this logic to suit other sources or use cases.
    if source == "poetry" and python and python ~= "" then
      -- Use vim.api.nvim_feedkeys to send the command into the terminal buffer.
      -- If you prefer to use `vim.fn.system()` or open a job, change accordingly.
      local cmd = "poetry env use " .. vim.fn.shellescape(python) .. "\n"
      -- Feed the keys in normal mode so a newly opened terminal receives them.
      vim.api.nvim_feedkeys(cmd, "n", false)
      command_run = true
    end
  end

  -- Create a dedicated augroup so the autocommand can be cleared/replaced safely.
  vim.api.nvim_create_augroup("VenvSelectorTerminalCommands", { clear = true })

  -- Trigger when entering a terminal. The callback will run once (controlled by command_run).
  vim.api.nvim_create_autocmd("TermEnter", {
    group = "VenvSelectorTerminalCommands",
    pattern = "*",
    callback = run_shell_command,
  })
end

-- Optional helper: register statusline components for pack-based configs that load
-- modules under a different path. If you want to require this file as:
-- `require("venv-selector.examples.statusline")` place it under that module path.
return M