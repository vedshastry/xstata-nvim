# xstata-nvim: Neovim Plugin for Stata Integration

A Neovim plugin that provides seamless integration with Stata, allowing you to send code from Neovim to a running Stata instance. Inspired by stata-exec for Atom/Pulsar.

## Features

- Send the current line, visual selection, or paragraph to Stata
- Run entire Stata do files directly from Neovim
- Automatically advance the cursor after sending code
- Skip comments when advancing the cursor
- Support for line continuations (`///`) and block comments
- Optimized for Linux and macOS (Windows support coming soon)

## Prerequisites

Curently supported for Linux. Experimental implementation on Mac OS
- Stata: StataSE, StataMP, or StataIC installed
- `xclip` for clipboard management
- `xdotool` for window management and keyboard control

Install them with:
```bash
# Debian/Ubuntu
sudo apt-get install xclip xdotool

# Fedora
sudo dnf install xclip xdotool

# Arch Linux
sudo pacman -S xclip xdotool
```

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

Add the following to your Neovim configuration:

```lua
{
  "vedshastry/xstata-nvim",
  config = function()
    require('xstata-nvim').setup({
      -- Configuration options (defaults shown)
      which_app = "StataMP", -- Options: StataMP, StataSE, StataIC, Stata
      advance_position = false, -- Move cursor to next line after sending current line
      skip_comments = true, -- Skip comment lines when advancing position
      focus_window = true, -- After code is sent, bring focus to Stata
    })
  end,
  ft = { "stata", "do", "ado", "mata" }, -- Load only for Stata file types
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'vedshastry/xstata-nvim',
  config = function() require('xstata-nvim').setup() end,
  ft = { "stata", "do", "ado", "mata" }
}
```

### Manual Installation

1. Clone the repository into your Neovim packages directory:

```bash
git clone https://github.com/vedshastry/xstata-nvim.git ~/.local/share/nvim/site/pack/plugins/start/xstata-nvim
```

2. Add the following to your init.lua:

```lua
require('xstata-nvim').setup({
  -- Your configuration options here
})
```

## Usage

### Default Commands

The plugin provides the following commands:

- `:StataRun` - Send the current line or visual selection to Stata
- `:StataRunAll` - Run the entire current buffer as a do-file
- `:StataRunParagraph` - Run the current paragraph (text block)
- `:StataRunPrevious` - Re-run the previous command

### Default Keybindings

- `<Leader>sr`: Run current line or visual selection
- `<Leader>sa`: Run entire buffer as a do-file
- `<Leader>sp`: Run current paragraph
- `<Leader>sc`: Run previous command

### Custom Keybindings

You can set up your own keybindings by adding them to your Neovim configuration:

```lua
-- Run current line or selection with Ctrl+Enter
vim.keymap.set('n', '<C-CR>', ':StataRun<CR>', {noremap = true, silent = true})
vim.keymap.set('v', '<C-CR>', ':StataRun<CR>', {noremap = true, silent = true})

-- Run entire buffer with Ctrl+Shift+D
vim.keymap.set('n', '<C-S-d>', ':StataRunAll<CR>', {noremap = true, silent = true})

-- Run paragraph with Ctrl+Alt+Enter
vim.keymap.set('n', '<C-A-CR>', ':StataRunParagraph<CR>', {noremap = true, silent = true})
```

## Configuration Options

You can customize the plugin behavior with these options:

```lua
require('xstata-nvim').setup({
  -- Stata application to use (macOS)
  which_app = "StataMP",  -- Options: StataMP, StataSE, StataIC, Stata

  -- Automatically move cursor to next line after sending code
  advance_position = false,

  -- Skip comment lines when advancing cursor
  skip_comments = true,

  -- After sending code, focus Stata window
  focus_window = true,
})
```

## Troubleshooting

### Common Issues

#### Linux

- If `xdotool` can't find the Stata window, try running the following command in the terminal to see if Stata is properly detected:
  ```bash
  xdotool search --name --limit 1 "Stata/"
  ```
  If this command doesn't return a window ID, you may need to adjust the search pattern in the `sender.lua` file.

#### macOS

- Make sure the application name in `which_app` matches exactly with the name of your Stata application.
- If code is not being sent to Stata, check that you have the necessary permissions for AppleScript to control Stata.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License

Copyright (c) 2025 Vedarshi Shastry
