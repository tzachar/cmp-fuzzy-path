# cmp-fuzzy-path

`nvim-cmp` source for filesystem paths, employing `fd` and regular expressions to
find files.

To facilitate fuzzy matching, when `cmp-fuzzy-path` tries to find a path the
path is first transformed to a regular expression like this: `p/t/f` -->
`p.*/.*t.*/.*f.'`, which will match `path/to/file` and also
`pa/toooo/other_file`.

# Installation

Using [Packer](https://github.com/wbthomason/packer.nvim/):
```lua
use {'tzachar/cmp-fuzzy-path', requires = {'hrsh7th/nvim-cmp'}}
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
    { name = 'fuzzy_path', opts = {fd_timeout_msec = 1500} }
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
