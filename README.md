# grug-far.nvim

**F**ind **A**nd **R**eplace plugin for neovim

<img width="500" alt="image" src="https://github.com/MagicDuck/grug-far.nvim/assets/95201/770900e2-36c6-488c-9117-5fcb514454cb">

Grug find! Grug replace! Grug happy!

## ✨ Features

- Search using the **full power** of `rg`
- Replace using almost the **full power** of `rg`. Some flags such as `--binary` and `--json`, etc. are [blacklisted][blacklistedReplaceFlags] in order to prevent unexpected output. The UI will warn you and prevent replace when using such flags.
- Open search results in quickfix list
- Goto file/line/column of match when pressing `<Enter>` in normal mode on lines in the results output (keybind configurable).

#### Searching:
<img width="100%" alt="image" src="https://github.com/MagicDuck/grug-far.nvim/assets/95201/b664f77c-6e12-4a4a-a179-ada2da204039">

#### Replacing:
<img width="100%" alt="image" src="https://github.com/MagicDuck/grug-far.nvim/assets/95201/c204caad-849c-47fc-89a3-99415fb7e4a9">

#### Help:
<img width="100%" alt="image" src="https://github.com/MagicDuck/grug-far.nvim/assets/95201/05e2108f-28b0-4e26-9c65-79eeedd394a3">

## 🤔 Philosophy

1. *strives for reduced mental overhead.* All actions you can take are in your face. As much help as possible is in your face (some configurable). Grug often forget how to do capture groups or which flag does what.
2. *transparency.* Does not try to hide away `rg` and shows error messages from it which are actually quite friendly when you mess up your regex. You can gradually learn `rg` flags or use existing knowledge from running it in the CLI. You can even input the `--help` flag to see the full `rg` help. Grug like!
3. *reuse muscle memory.* Does not try to block any type of buffer edits, such as deleting lines, etc. It's very easy to get such things wrong and when you do, Grug becomes unable to modify text in the middle of writing a large regex. Grug mad!! Only ensures graceful recovery in order to preserve basic UI integrity (possible due to the magic of extmarks). Recovery should be simple undo away. 
4. *uniformity.* only uses one tool, `rg`, and does not combine with other tools like `sed`. One should not have to worry about compatibility differences when writing regexes. Additionally it opens the door to use to many fancy `rg` flags such as different regex engine that would not be possible in a mixed environment. Replacement is achieved by running `rg --passthrough` on each file with configurable number of parallel workers.


## ⚡️ Requirements

- Neovim >= **0.9.0** (might work with lower versions)
- [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)
- a [Nerd Font](https://www.nerdfonts.com/) **_(optional)_**

Run `:checkhealth grug-far` if you see unexpected issues.

## 📦 Installation

Using [lazy.nvim][lazy]:
```lua
  {
    'MagicDuck/grug-far.nvim',
    config = function()
      require('grug-far').setup({
        ... options, see Configuration section below ...
      });
    end
  },

```

## ⚙️ Configuration

**grug-far.nvim** comes with the following:
- [default options][opts] 
- [highlights][highlights]

## 🚀 Usage

You can open a new *grug-far.nvim* vertical split buffer with the `:GrugFar` command. But possibly
best to map a keybind to it for easy triggering.
Since it's *just a buffer*, you can edit in it as you see fit. The UI will try to guide
you along and recover gracefully if you do things like `ggVGd` (delete all lines).
Ultimately it leaves the power in your hands, and in any case recovery is just a few `u` taps away.

Search and replace to your heart's desire. You can create multiple such buffers with potentially
different searches, which will reflect in each buffer's title (configurable). The buffers should
be visible in the buffers list if you need to toggle to them. When you are done, it is recommended
to close the buffer with the configured keybinding (see Configuration section above) or just `:bd`
in order to save on resources as some search results can be quite beefy in size.

## 📦 Similar Plugins / Inspiration

- [nvim-spectre][spectre]
- [telescope.nvim][telescope]: lifted `rg` healthcheck from there :P
- [lazy.nvim][lazy]: used their beautiful `README.md` as a template

[help]: doc/my-awesome-plugin.txt
[opts]: lua/grug-far/opts.lua
[highlights]: lua/grug-far/highlights.lua
[lazy]: https://github.com/folke/lazy.nvim
[spectre]: https://github.com/nvim-pack/nvim-spectre
[telescope]: https://github.com/nvim-telescope/telescope.nvim
[blacklistedReplaceFlags]: lua/grug-far/rg/blacklistedReplaceFlags.lua 
