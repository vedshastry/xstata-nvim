# xstata-nvim: Neovim Plugin for Stata Integration

This plugin allows you to send Stata code from Neovim to a running Stata instance, similar to how stata-exec works for Atom/Pulsar.

## Features

- Send the current line or visual selection to Stata
- Run entire Stata do files
- Run the current paragraph (block of text)
- Automatically advance the cursor after sending a line
- Skip comment lines when advancing
- Cross-platform support (primary focus on Linux and macOS)

## Prerequisites

### macOS

- For XQuartz: Ensure XQuartz is installed
- For Stata: No additional dependencies

### Linux

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

### Using Lazy.nvim

Add the following to your Neovim configuration:

```lua
{
  "vedshastry/xstata-nvim",
  config = function()
    require('xstata-nvim').setup({
      -- Configuration options (defaults shown)
      which_app = "StataMP", -- Options: StataMP, StataSE, StataIC, Stata, XQuartz
      advance_position = false, -- Move cursor to next line after sending current line
      skip_comments = true, -- Skip comment lines when advancing position
      focus_window = true, -- After code is sent, bring focus to Stata
      paste_speed = 1.0, -- Only for XQuartz - adjust delay timing for pasting
    })
  end,
}
```

### Manual Installation

1. Create directories for the plugin:

```bash
mkdir -p ~/.config/nvim/lua/xstata-nvim
```

2. Save the xstata-nvim.lua file to ~/.config/nvim/lua/xstata-nvim/init.lua

3. Add the following to your init.lua:

```lua
require('xstata-nvim').setup({
  -- Your configuration options here
})
```

## Usage

### Default Keybindings

- `<Leader>rs`: Send the current line or visual selection to Stata
- `<Leader>rc`: Run the previous command
- `<Leader>ra`: Run all (entire buffer)
- `<Leader>rp`: Run the current paragraph

### Custom Keybindings

You can set up your own keybindings by adding them to your Neovim configuration:

```lua
-- Run current line or selection with a different key
vim.api.nvim_set_keymap('n', '<F5>', '<cmd>lua require("xstata-nvim").run()<CR>', {noremap = true, silent = true})
vim.api.nvim_set_keymap('v', '<F5>', '<cmd>lua require("xstata-nvim").run()<CR>', {noremap = true, silent = true})

-- Run entire buffer
vim.api.nvim_set_keymap('n', '<F6>', '<cmd>lua require("xstata-nvim").run_all()<CR>', {noremap = true, silent = true})
```

## Troubleshooting

### Common Issues

#### Linux

- If `xdotool` can't find the Stata window, try running the following command in the terminal to see if Stata is properly detected:
  ```bash
  xdotool search --name --limit 1 "Stata/(IC|SE|MP)? 1[0-9]\.[0-9]"
  ```
  If this command doesn't return a window ID, you may need to adjust the search pattern.

#### macOS

- For XQuartz, you may need to adjust the paste_speed setting if the code isn't being pasted correctly.
- Make sure the application name in `which_app` matches exactly with the name of your Stata application.

## Contributing

Pull requests for bug fixes and new features are welcome!

## License

GPL v3
