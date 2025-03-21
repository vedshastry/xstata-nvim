-- xstata-nvim/sender.lua
-- OS-specific implementations for sending code to Stata

local M = {}

-- References to config (will be set by init.lua)
M.config = {}

-----------------
-- Linux Support
-- requires `xdotool` to send code to Stata window
-----------------

-- Function to send code to Stata in Linux
function M.send_linux(text, is_file_path)
  -- For running a do file
  if is_file_path then
    os.execute(string.format(
      "stata_window=$(xdotool search --name --limit 1 \"Stata/\") && " ..
      "xdotool type --window $stata_window --clearmodifiers --delay 5 'do \"%s\"' && " ..
      "xdotool key  --window $stata_window --delay 5 Return",
      text:gsub('"', '\\"'):gsub('`', '\\`')
    ))
    return
  end

  -- For selected text, use xdotool's clipboard buffer
  -- Save the original clipboard content
  os.execute("original_clipboard=$(xclip -o -selection clipboard 2>/dev/null || echo '')")

  -- Write the text to the clipboard
  local clipboard_cmd = string.format("echo -n '%s' | xclip -selection clipboard",
    text:gsub("'", "'\\''")) -- Escape single quotes for shell
  os.execute(clipboard_cmd)

  -- Send to Stata window using clipboard paste
  os.execute(string.format(
    "this_window=$(xdotool getactivewindow) && " ..
    "stata_window=$(xdotool search --name --limit 1 \"Stata/\") && " ..
    "xdotool windowactivate $stata_window && " ..
    "xdotool key --window $stata_window --clearmodifiers --delay 20 ctrl+v && " ..
    "xdotool key --window $stata_window --delay 5 Return &&" ..
    "xdotool windowactivate --sync $this_window "
  ))

  -- Restore original clipboard content
  os.execute("echo -n \"$original_clipboard\" | xclip -selection clipboard")

  -- Return focus to Neovim if needed
  if not M.config.focus_window then
    os.execute("this_window=$(xdotool getactivewindow) && xdotool windowactivate --sync $this_window")
  end
end

-----------------
-- Mac Support
-----------------

-- Function to send code to Stata in MacOS
function M.send_mac(text, is_file_path)
  local which_app = M.config.which_app

  -- For running a do file
  if is_file_path then
    local focus_cmd = ""
    if M.config.focus_window then
      focus_cmd = string.format('tell application "%s" to activate\n', which_app)
    end

    local cmd = focus_cmd .. string.format('tell application "%s" to DoCommandAsync "do `\\"%s\\"`"', which_app, text)

    -- Execute the AppleScript
    vim.fn.system({'osascript', '-e', cmd})
    return
  end

  -- For regular code execution
  -- Escape double quotes and other special characters
  text = text:gsub('"', '\\"')

  local focus_cmd = ""
  if M.config.focus_window then
    focus_cmd = string.format('tell application "%s" to activate\n', which_app)
  end

  local cmd = focus_cmd .. string.format('tell application "%s" to DoCommandAsync "%s"', which_app, text)

  -- Execute the AppleScript
  vim.fn.system({'osascript', '-e', cmd})
end

-----------------
-- Windows Support
-----------------

-- Function to send code to Stata in Windows (stub)
function M.send_windows(text, is_file_path)
  vim.notify('Windows support not implemented yet', vim.log.levels.WARN)
end

-- Main function to send code to Stata based on OS
function M.send_code(text, is_file_path, os_name)
  -- Execute codeblock based on OS
  if os_name == 'linux' then
    M.send_linux(text, is_file_path)
  elseif os_name == 'mac' then
    M.send_mac(text, is_file_path)
  elseif os_name == 'windows' then
    M.send_windows(text, is_file_path)
  else
    vim.notify('Unsupported operating system', vim.log.levels.ERROR)
  end
end

return M
