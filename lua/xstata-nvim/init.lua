-- xstata-nvim.lua
-- A Neovim plugin to send Stata code to a running Stata instance
-- Inspired by stata-exec for Atom/Pulsar by Kyle Barron

local M = {}

-- Configuration variables with defaults
M.config = {
  which_app = "StataMP", -- Options: StataMP, StataSE, StataIC, Stata, XQuartz
  advance_position = false, -- Move cursor to next line after sending current line
  skip_comments = true, -- Skip comment lines when advancing position
  focus_window = true, -- After code is sent, bring focus to Stata
  paste_speed = 1.0, -- Only for XQuartz - adjust delay timing for pasting
}

-- Detect operating system
local function get_os()
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

local os_name = get_os()

-- Function to process Stata code 
local function process_stata_code(text)
  -- First, handle line continuations with ///
  -- Replace /// and everything after it until the end of line with a space
  text = text:gsub("///.-\n%s*", " ")
  
  -- Remove block comments /* ... */
  text = text:gsub("/%*.-*%/", "")
  
  -- Remove line comments // ...
  text = text:gsub("//.-\n", "\n")
  
  -- Clean up extra whitespace
  text = text:gsub("%s+", " ")
  
  return text
end

-- Function to send code to Stata in MacOS
local function send_mac(text, is_file_path)
  local which_app = M.config.which_app
  
  if which_app == "XQuartz" then
    return send_xquartz(text, is_file_path)
  end
  
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

-- Function to send code to Stata via XQuartz
local function send_xquartz(text, is_file_path)
  -- For running a do file
  if is_file_path then
    -- Format the do command with proper escaping
    text = string.format('do `"%s"`', text)
  end
  
  -- Escape double quotes and other special characters
  text = text:gsub('"', '\\"')
  
  local paste_speed = M.config.paste_speed
  local focus_window = M.config.focus_window
  
  local cmd = string.format([[
    set current_clipboard to the clipboard
    set the clipboard to ("%s" as text)
    tell application "XQuartz" to activate
    delay 0.4 * %s
    tell application "System Events" to keystroke "v" using control down
    delay 0.9 * %s
    tell application "System Events" to keystroke return
    delay 0.1 * %s
  ]], text, paste_speed, paste_speed, paste_speed)
  
  if not focus_window then
    cmd = cmd .. '\ntell application "Neovim" to activate'
  end
  
  cmd = cmd .. '\nset the clipboard to current_clipboard'
  
  -- Execute the AppleScript
  vim.fn.system({'osascript', '-e', cmd})
end

-- Function to send code to Stata in Linux
local function send_linux(text, is_file_path)
  if is_file_path then
    -- For a do file, just send the do command directly
    local cmd = string.format([[
      old_cb="$(xclip -o -selection clipboard)";
      this_window="$(xdotool getactivewindow)" &&
      stata_window="$(xdotool search --name --limit 1 "Stata/(IC|SE|MP)? [0-9][0-9]\.[0-9]")" &&
      echo "do \`\"%s\"'" | xclip -i -selection clipboard &&
      xdotool \
        keyup ctrl shift \
        windowactivate $stata_window \
        key --window $stata_window --clearmodifiers --delay 20 ctrl+v Return \
        windowactivate --sync $this_window;
      printf "$old_cb" | xclip -i -selection clipboard
    ]], text)
    
    vim.fn.jobstart(cmd, {
      on_exit = function(_, code)
        if code ~= 0 then
          vim.notify('Failed to send do file command to Stata', vim.log.levels.ERROR)
        end
      end
    })
    return
  end
  
  -- Save the code to a temporary file
  local temp_file = vim.fn.expand('~/.xstata-nvim-code')
  local file = io.open(temp_file, 'w')
  if not file then
    vim.notify('Failed to write temporary file', vim.log.levels.ERROR)
    return
  end
  file:write(text)
  file:close()
  
  -- Use xdotool to send the code to Stata
  local cmd = string.format([[
    old_cb="$(xclip -o -selection clipboard)";
    this_window="$(xdotool getactivewindow)" &&
    stata_window="$(xdotool search --name --limit 1 "Stata/(IC|SE|MP)? [0-9][0-9]\.[0-9]")" &&
    cat %s | xclip -i -selection clipboard &&
    xdotool \
      keyup ctrl shift \
      windowactivate $stata_window \
      key --window $stata_window --clearmodifiers --delay 20 ctrl+v Return \
      windowactivate --sync $this_window;
    printf "$old_cb" | xclip -i -selection clipboard
  ]], temp_file)
  
  vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if code ~= 0 then
        vim.notify('Failed to send code to Stata', vim.log.levels.ERROR)
      end
    end
  })
end

-- Main function to send code to Stata
function M.send_code(text, is_file_path)
  if not is_file_path then
    -- Process the code to handle line continuations and comments
    text = process_stata_code(text)
  end
  
  -- Store the previous command
  M.previous_command = text
  
  -- Send the code based on the OS
  if os_name == 'mac' then
    send_mac(text)
  elseif os_name == 'linux' then
    send_linux(text, is_file_path)
  elseif os_name == 'windows' then
    vim.notify('Windows support not implemented yet', vim.log.levels.WARN)
  else
    vim.notify('Unsupported operating system', vim.log.levels.ERROR)
  end
end

-- Function to run the current line or selection
function M.run()
  local current_buf = vim.api.nvim_get_current_buf()
  local selection = vim.fn.getregion("v", ".")
  
  if #selection > 0 then
    -- There is a visual selection
    local text = table.concat(selection, "\n")
    M.send_code(text, false)
  else
    -- No selection, use current line
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_buf_get_lines(current_buf, cursor_pos[1] - 1, cursor_pos[1], false)[1]
    M.send_code(line, false)
      -- Advance position if configured
      if M.config.advance_position then
        local next_line = cursor_pos[1]
        local max_line = vim.api.nvim_buf_line_count(current_buf)
        
        while next_line < max_line do
          next_line = next_line + 1
          local line_text = vim.api.nvim_buf_get_lines(current_buf, next_line - 1, next_line, false)[1]
          
          -- Skip comment lines if configured
          if not M.config.skip_comments or not line_text:match("^%s*[/*]") then
            vim.api.nvim_win_set_cursor(0, {next_line, 0})
            break
          end
        end
      end
  end
end

-- Function to run the previous command
function M.run_previous_command()
  if M.previous_command then
    M.send_code(M.previous_command)
  else
    vim.notify('No previous command to run', vim.log.levels.WARN)
  end
end

-- Function to run the entire buffer
function M.run_all()
  local current_buf = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(current_buf)
  
  if file_path == "" then
    vim.notify("File must be saved before running the entire file", vim.log.levels.ERROR)
    return
  end
  
  -- Auto-save the file if it's dirty
  if vim.bo[current_buf].modified then
    vim.cmd("write")
  end
  
  -- Send the file path directly to Stata
  M.send_code(file_path, true)
end

-- Function to run the current paragraph
function M.run_paragraph()
  local current_buf = vim.api.nvim_get_current_buf()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local current_line = cursor_pos[1]
  local total_lines = vim.api.nvim_buf_line_count(current_buf)
  
  -- Find start of paragraph (first empty line above current line)
  local start_line = current_line
  while start_line > 1 do
    local line = vim.api.nvim_buf_get_lines(current_buf, start_line - 2, start_line - 1, false)[1]
    if line:match("^%s*$") then
      break
    end
    start_line = start_line - 1
  end
  
  -- Find end of paragraph (first empty line below current line)
  local end_line = current_line
  while end_line < total_lines do
    local line = vim.api.nvim_buf_get_lines(current_buf, end_line, end_line + 1, false)[1]
    if line:match("^%s*$") then
      break
    end
    end_line = end_line + 1
  end
  
  -- Get the paragraph text
  local paragraph = vim.api.nvim_buf_get_lines(current_buf, start_line - 1, end_line, false)
  local text = table.concat(paragraph, "\n")
  
  -- Process and send the code
  M.send_code(text, false)
  
  -- Advance position if configured
  if M.config.advance_position then
    vim.api.nvim_win_set_cursor(0, {end_line + 1, 0})
  end
end

function M.setup_keymaps()
  -- Run current line or selection
  vim.api.nvim_set_keymap('n', '<Leader>rr', '<cmd>lua require("xstata-nvim").run()<CR>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('v', '<Leader>rr', '<cmd>lua require("xstata-nvim").run()<CR>', {noremap = true, silent = true})
  
  -- Run entire buffer
  vim.api.nvim_set_keymap('n', '<Leader>ra', '<cmd>lua require("xstata-nvim").run_all()<CR>', {noremap = true, silent = true})
  
  -- Run current paragraph
  vim.api.nvim_set_keymap('n', '<Leader>rp', '<cmd>lua require("xstata-nvim").run_paragraph()<CR>', {noremap = true, silent = true})
  
  -- Run previous command
  vim.api.nvim_set_keymap('n', '<Leader>rc', '<cmd>lua require("xstata-nvim").run_previous_command()<CR>', {noremap = true, silent = true})
end

-- Setup function to initialize the plugin
function M.setup(opts)
  -- Merge user config with defaults
  if opts then
    M.config = vim.tbl_deep_extend('force', M.config, opts)
  end
  
  -- Set up keymaps
  M.setup_keymaps()
end

return M
