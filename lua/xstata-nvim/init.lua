-- xstata-nvim/init.lua
-- Main entry point for the Neovim plugin to send Stata code to a running Stata instance
-- Inspired by stata-exec for Atom/Pulsar by Kyle Barron

local utils = require("xstata-nvim.utils")
local sender = require("xstata-nvim.sender")

local M = {}

-- Configuration variables with defaults
M.config = {
  which_app = "StataMP", -- Options: StataMP, StataSE, StataIC, Stata
  advance_position = false, -- Move cursor to next line after sending current line
  skip_comments = true, -- Skip comment lines when advancing position
  focus_window = true, -- After code is sent, bring focus to Stata
}

-- Determine OS
local os_name = utils.get_os()

-- Store the previous command
M.previous_command = nil

-- Main function to send code to Stata
function M.send_code(text, is_file_path)
  -- Don't clean do-files
  if not is_file_path then
    text = utils.clean_codeblock(text)
  end

  -- Store the previous command
  M.previous_command = text

  -- Use the sender module to send the code
  sender.send_code(text, is_file_path, os_name)
end

-- Function to run the current line
function M.run_current()
  local current_buf = vim.api.nvim_get_current_buf()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(current_buf, cursor_pos[1] - 1, cursor_pos[1], false)[1]

  if line and line ~= "" then
    M.send_code(line, false)

    -- Advance position if configured
    if M.config.advance_position then
      local next_line = cursor_pos[1]
      local max_line = vim.api.nvim_buf_line_count(current_buf)

      while next_line < max_line do
        next_line = next_line + 1
        local line_text = vim.api.nvim_buf_get_lines(current_buf, next_line - 1, next_line, false)[1]

        -- Skip comment lines if configured
        if not M.config.skip_comments or not (line_text and line_text:match("^%s*[/*]")) then
          vim.api.nvim_win_set_cursor(0, {next_line, 0})
          break
        end
      end
    end
  else
    vim.notify("Empty line", vim.log.levels.WARN)
  end
end

-- Function to run selected text
function M.run_selected()
  local current_buf = vim.api.nvim_get_current_buf()
  local mode = vim.api.nvim_get_mode().mode

  -- Make sure we're in visual mode
  if not mode:match("^[vV\22]") then
    vim.notify("Not in visual mode", vim.log.levels.WARN)
    return
  end

  -- Get selection boundaries
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2] - 1
  local end_line = end_pos[2]

  -- Get the selected lines
  local lines = vim.api.nvim_buf_get_lines(current_buf, start_line, end_line, false)

  -- If we're in visual block mode (ctrl-v), handle it differently
  if mode == "\22" then
    local start_col = start_pos[3] - 1
    local end_col = end_pos[3]

    -- Extract only the selected portion of each line
    for i = 1, #lines do
      if start_col < #lines[i] then
        local line_end = math.min(end_col, #lines[i])
        lines[i] = lines[i]:sub(start_col + 1, line_end)
      else
        lines[i] = ""
      end
    end
  end

  -- Join the lines with explicit newlines to preserve line breaks
  local text = table.concat(lines, "\n")
  if text ~= "" then
    M.send_code(text, false)
  else
    vim.notify("No text selected", vim.log.levels.WARN)
  end

  -- Exit visual mode and return to normal mode
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
end

-- Function to run the entire buffer
function M.run_all()
  local current_buf = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(current_buf)

  if file_path == "" then
    vim.notify("File must be saved before running the entire file", vim.log.levels.ERROR)
    return
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

  -- Send code
  M.send_code(text, false)

  -- Advance position if configured
  if M.config.advance_position then
    vim.api.nvim_win_set_cursor(0, {end_line + 1, 0})
  end
end

-- Function to run the previous command
function M.run_previous()
  if M.previous_command then
    M.send_code(M.previous_command, false)
  else
    vim.notify('No previous command to run', vim.log.levels.WARN)
  end
end

-- Function to run the current line or selection
function M.run()
  local mode = vim.api.nvim_get_mode().mode

  if mode:match("^[vV\22]") then  -- v, V, or ctrl-v mode
    M.run_selected()
  else
    M.run_current()
  end
end

-- Setup keymaps
function M.setup_keymaps()
  -- Create user commands for more reliable operation
  vim.api.nvim_create_user_command('StataRun', function()
    require("xstata-nvim").run()
  end, { range = true })

  vim.api.nvim_create_user_command('StataRunAll', function()
    require("xstata-nvim").run_all()
  end, {})

  vim.api.nvim_create_user_command('StataRunParagraph', function()
    require("xstata-nvim").run_paragraph()
  end, {})

  vim.api.nvim_create_user_command('StataRunPrevious', function()
    require("xstata-nvim").run_previous()
  end, {})

  -- Map to user commands
  vim.api.nvim_set_keymap('n', '<Leader>sr', ':StataRun<CR>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('v', '<Leader>sr', ':StataRun<CR>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('n', '<Leader>sa', ':StataRunAll<CR>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('n', '<Leader>sp', ':StataRunParagraph<CR>', {noremap = true, silent = true})
  vim.api.nvim_set_keymap('n', '<Leader>sc', ':StataRunPrevious<CR>', {noremap = true, silent = true})
end

-- Setup function to initialize the plugin
function M.setup(opts)
  -- Merge user config with defaults
  if opts then
    M.config = vim.tbl_deep_extend('force', M.config, opts)
  end

  -- Share the config with the sender module
  sender.config = M.config

  -- Set up keymaps
  M.setup_keymaps()
end

return M
