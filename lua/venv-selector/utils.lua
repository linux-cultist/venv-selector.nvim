-- lua/venv-selector/utils.lua
--
-- Small utility helpers used across venv-selector.nvim.
--
-- Responsibilities:
-- - Generic table helpers.
-- - Safe nested table access.
-- - Command string splitting (with basic quote handling).
-- - Debug table printing.
--
-- Notes:
-- - These utilities are intentionally dependency-light.
-- - Some functionality (like Windows splitting) is currently thin wrappers,
--   but kept for future extensibility.
require("venv-selector.types")

local log = require("venv-selector.logger")

local M = {}

-- ============================================================================
-- Table helpers
-- ============================================================================

---Check whether a table contains at least one key.
---
---@param t table|nil The table to check
---@return boolean has_content True if table is non-nil and not empty
function M.table_has_content(t)
    return t ~= nil and next(t) ~= nil
end

-- ============================================================================
-- String / command splitting
-- ============================================================================

---Split a string into whitespace-separated parts,
---while respecting single and double quotes.
---
---Example:
---  split_string([[cmd "arg with space" 'another one']])
---  -> { "cmd", "arg with space", "another one" }
---
---Quotes are not included in the resulting tokens.
---
---@param str string The string to split
---@return string[] parts
function M.split_string(str)
    local result = {}
    local buffer = ""
    local in_quotes = false
    local quote_char = nil
    local i = 1

    while i <= #str do
        local c = str:sub(i, i)

        if c == "'" or c == '"' then
            if in_quotes then
                if c == quote_char then
                    -- Closing matching quote.
                    in_quotes = false
                    quote_char = nil
                else
                    -- Different quote inside quoted region.
                    buffer = buffer .. c
                end
            else
                -- Opening quote.
                in_quotes = true
                quote_char = c
            end
        elseif c == " " then
            if in_quotes then
                buffer = buffer .. c
            else
                if #buffer > 0 then
                    table.insert(result, buffer)
                    buffer = ""
                end
            end
        else
            buffer = buffer .. c
        end

        i = i + 1
    end

    -- Append trailing token.
    if #buffer > 0 then
        table.insert(result, buffer)
    end

    return result
end

---Split a command string for Windows execution.
---Currently just delegates to split_string, but exists
---as a dedicated entrypoint for future platform-specific logic.
---
---@param str string
---@return string[] parts
function M.split_cmd_for_windows(str)
    return M.split_string(str)
end

-- ============================================================================
-- Safe nested access
-- ============================================================================

---Safely access nested table keys.
---
---Example:
---  M.try(tbl, "a", "b", "c")
---  -> returns tbl.a.b.c or nil if any level is missing.
---
---@param tbl table The root table
---@param ... string Keys to follow
---@return any|nil value
function M.try(tbl, ...)
    local result = tbl
    for _, key in ipairs({ ... }) do
        if result and type(result) == "table" then
            result = result[key]
        else
            return nil
        end
    end
    return result
end

-- ============================================================================
-- Debug helpers
-- ============================================================================

---Recursively print a table to stdout (not to logger buffer).
---Intended for quick debugging during development.
---
---@param tbl table
---@param indent? integer
function M.print_table(tbl, indent)
    indent = indent or 0

    for k, v in pairs(tbl) do
        local formatting = string.rep("  ", indent) .. tostring(k) .. ": "
        if type(v) == "table" then
            print(formatting)
            M.print_table(v, indent + 1)
        else
            print(formatting .. tostring(v))
        end
    end
end

return M
