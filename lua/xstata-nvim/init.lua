-- xstata-nvim.lua
-- A Neovim plugin to send Stata code to a running Stata instance
-- Inspired by stata-exec for Atom/Pulsar

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

-- Function to remove comments from Stata code
local function remove_comments(text)
  -- Remove block comments /* ... */
  text = text:gsub("/%*.-*%/", "")
  
  -- Remove line comments // ...
  text = text:gsub("//.-\n", "\n")
  
  -- Remove /// comments
  text = text:gsub("///.-\n", "\n")
  
  return text
end

-- Function to send code to Stata in MacOS
local function send_mac(text)
  local which_app = M.config.which_app
  
  if which_app == "XQuartz" then
    return send_xquartz(text)
  end
  
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
local function send_xquartz(text)
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
local function send_linux(text)
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
    stata_window="$(xdotool search --name --limit 1 "Stata/(IC|SE|MP)? 1[0-9]\.[0-9]")" &&
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
function M.send_code(text)
  -- Remove comments if configured
  text = remove_comments(text)
  
  -- Store the previous command
  M.previous_command = text
  
  -- Send the code based on the OS
  if os_name == 'mac' then
    send_mac(text)
  elseif os_name == 'linux' then
    send_linux(text)
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
    M.send_code(text)
  else
    -- No selection, use current line
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_buf_get_lines(current_buf, cursor_pos[1] - 1, cursor_pos[1], false)[1]
    M.send_code(line)
    
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
  local lines = vim.api.nvim_buf_get_lines(current_buf, 0, -1, false)
  local text = table.concat(lines, "\n")
  M.send_code(text)
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
  
  M.send_code(text)
  
  -- Advance position if configured
  if M.config.advance_position then
    vim.api.nvim_win_set_cursor(0, {end_line + 1, 0})
  end
end

-- Function to set up keymaps
function M.setup_keymaps()
  -- Run current line or selection with Ctrl+Enter
  vim.api.nvim_set_keymap('n', '<C-CR>', '<cmd>lua require("xstata-nvim").run()<CR>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('v', '<C-CR>', '<cmd>lua require("xstata-nvim").run()<CR>', {noremap = true, silent = true})
  
  -- Run previous command
  vim.api.nvim_set_keymap('n', '<Leader>rp', '<cmd>lua require("xstata-nvim").run_previous_command()<CR>', {noremap = true, silent = true})
  
  -- Run entire buffer
  vim.api.nvim_set_keymap('n', '<Leader>ra', '<cmd>lua require("xstata-nvim").run_all()<CR>', {noremap = true, silent = true})
  
  -- Run current paragraph
  vim.api.nvim_set_keymap('n', '<Leader>rr', '<cmd>lua require("xstata-nvim").run_paragraph()<CR>', {noremap = true, silent = true})
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
