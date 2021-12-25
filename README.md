# cmp-fuzzy-path

`nvim-cmp` source for filesystem paths.

# Installation

Depends on [fuzzy.nvim](https://github.com/tzachar/fuzzy.nvim) (which depends
either on `fzf` or on `fzy`).

You should also have `fd` in your `PATH`.

Using [Packer](https://github.com/wbthomason/packer.nvim/) with `fzf`:
```lua
use {'nvim-telescope/telescope-fzf-native.nvim', run = 'make'}
use {'tzachar/cmp-fuzzy-path', requires = {'hrsh7th/nvim-cmp', 'tzachar/fuzzy.nvim'}}
```

Using [Packer](https://github.com/wbthomason/packer.nvim/) with `fzy`:
```lua
use {'romgrk/fzy-lua-native', run = 'make'}
use {'tzachar/cmp-fuzzy-path', requires = {'hrsh7th/nvim-cmp', 'tzachar/fuzzy.nvim'}}
```

# Setup

```lua
require'cmp'.setup {
  sources = cmp.config.sources({
    { name = 'fuzzy_path'},
  })
}
```

This plugin can also be used to complete file names for `:edit` or `:write` in cmdline mode of cmp:
```lua
cmp.setup.cmdline(':', {
  sources = cmp.config.sources({
    { name = 'fuzzy_path' }
  })
})
```

*Note:* the plugin's name is `fuzzy_path` in `cmp`'s config.


# Configuration

Configuration can be passed when configuring `cmp`:

```lua
cmp.setup.cmdline(':', {
  sources = cmp.config.sources({
    { name = 'fuzzy_path', opts = {fd_timeout_msec = 1500} }
  })
})
```

## fd_timeout_msec (type: int)

_Default:_ 500

How much grace to give the file finder before killing it. If you set this to too
short a value, you will probably not get enough suggestions.

## fd_cmd (type: table(string))

_Default:_ `{'fd', '-d', '20'}`

The commend to use as a file finder.
