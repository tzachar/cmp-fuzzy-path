# cmp-fuzzy-path

`nvim-cmp` source for filesystem paths.

# Installation

Depends on [fuzzy.nvim](https://github.com/tzachar/fuzzy.nvim) (which depends
either on `fzf` or on `fzy`).

Using [Packer](https://github.com/wbthomason/packer.nvim/) with `fzf`:
```lua
use {'nvim-telescope/telescope-fzf-native.nvim', run = 'make'}
use "hrsh7th/nvim-cmp"
use {'tzachar/cmp-fuzzy-path', requires = {'hrsh7th/nvim-cmp', 'tzachar/fuzzy.nvim'}}
```

Using [Packer](https://github.com/wbthomason/packer.nvim/) with `fzy`:
```lua
use {'romgrk/fzy-lua-native', run = 'make'}
use "hrsh7th/nvim-cmp"
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
cmp.setup.cmdline('/', {
  sources = cmp.config.sources({
    { name = 'fuzzy_path' }
  })
})
```

*Note:* the plugin's name is `fuzzy_path` in `cmp`'s config.
