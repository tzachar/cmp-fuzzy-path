# cmp-fuzzy-path

`nvim-cmp` source for filesystem paths, employing `fd` and regular expressions to
find files.

Depends on [fuzzy.nvim](https://github.com/tzachar/fuzzy.nvim) (which depends
either on `fzf` or on `fzy`).

To facilitate fuzzy matching, when `cmp-fuzzy-path` tries to find a path the
path is first transformed to a regular expression like this: `p/t/f` -->
`p.*/.*t.*/.*f.'`, which will match `path/to/file` and also
`pa/toooo/other_file`.

# Installation

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

You should have `fd` in your `PATH`, or edit the configuation to point at the
exact location.


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
    { name = 'fuzzy_path', options = {fd_timeout_msec = 1500} }
  })
})
```

## fd_timeout_msec (type: int)

_Default:_ 500

How much grace to give the file finder before killing it. If you set this to too
short a value, you will probably not get enough suggestions.

## fd_cmd (type: table(string))

_Default:_ `{'fd', '-d', '20', '-p'}`

The commend to use as a file finder. Note that `-p` is needed so we match on the
entire path, not just on the file or directory name.

# Sorting

`cmp-fuzzy-path` adds a score entry to each completion item's `data` field,
which can be used to override `cmp`'s default sorting order:


```lua
local compare = require('cmp.config.compare')
cmp.setup({
  sorting = {
    priority_weight = 2,
    comparators = {
      require('cmp_fuzzy_path.compare'),
      compare.offset,
      compare.exact,
      compare.score,
      compare.recently_used,
      compare.kind,
      compare.sort_text,
      compare.length,
      compare.order,
    },
  },
}
```

# Commands

`cmp-fuzzy-path` add the following commands:

## `CmpFuzzyStats`

`CmpFuzzyStats` can be used to gather statistics about the operation of the
plugin. Output contains the following: 

- Total Usage Count: how many times the plugin was called
- Timeout Count: how many times we reached a timeout
- Average Search Time: the average time it took to complete the search
