-- xstata-nvim/utils.lua
-- Utility functions for the plugin

local M = {}

-- Detect operating system
function M.get_os()
  if vim.fn.has('mac') == 1 then
    return 'mac'
  elseif vim.fn.has('unix') == 1 then
    return 'linux'
  elseif vim.fn.has('win32') == 1 then
    return 'windows'
  else
    return 'unknown'
  end
end

-- Function to clean and process Stata code
function M.clean_codeblock(text)
  -- First, handle line continuations with ///
  -- Replace /// and everything after it until the end of line with a space
  text = text:gsub("///.-\n%s*", " ")

  -- Remove block comments /* ... */
  text = text:gsub("/%*.-*%/", "")

  -- Remove line comments // ...
  text = text:gsub("//.-\n", "\n")

  -- Clean up extra whitespace, but preserve newlines
  text = text:gsub(" +", " ")      -- Multiple spaces to single space
  text = text:gsub("\t+", " ")     -- Tabs to space
  text = text:gsub("^ +", "")      -- Leading spaces
  text = text:gsub(" +$", "")      -- Trailing spaces
  text = text:gsub("\n +", "\n")   -- Leading spaces after newlines

  return text
end

return M
