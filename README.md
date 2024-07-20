# grug-far.nvim

**F**ind **A**nd **R**eplace plugin for neovim

<img width="500" alt="image" src="https://github.com/MagicDuck/grug-far.nvim/assets/95201/770900e2-36c6-488c-9117-5fcb514454cb">

Grug find! Grug replace! Grug happy!

## ✨ Features

- Search using the **full power** of `rg`
- Replace using almost the **full power** of `rg`. Some flags such as `--binary` and `--json`, etc. are [blacklisted][blacklistedReplaceFlags] in order to prevent unexpected output. The UI will warn you and prevent replace when using such flags.
- Open search results in quickfix list
- Goto file/line/column of match when pressing `<Enter>` in normal mode on lines in the results output (keybind configurable).
- Inline edit result lines and sync them back to their originating file locations using a configurable keybinding.
- Manual/auto-save search history and reload

#### Searching:
<img width="1261" alt="image" src="https://github.com/user-attachments/assets/4797b3ae-9243-4ea3-8733-17806b2f6df6">

#### Replacing:
<img width="1260" alt="image" src="https://github.com/user-attachments/assets/6afa304a-1441-4f55-81ca-e5f650fbf0fd">

#### Rg teaching you it's ways
<img width="1240" alt="image" src="https://github.com/user-attachments/assets/c658e4a5-462e-4297-a70b-0a7bced70d27">

#### Help:
<img width="1255" alt="image" src="https://github.com/user-attachments/assets/cd5f81e7-add2-4d27-9114-f403fccdd3d6">

#### History:
<img width="1256" alt="image" src="https://github.com/user-attachments/assets/5c323aef-a66a-4181-a3a5-3cb0fd22f5b9">


## 🤔 Philosophy

1. *strives for reduced mental overhead.* All actions you can take are in your face. As much help as possible is in your face (some configurable). Grug often forget how to do capture groups or which flag does what.
2. *transparency.* Does not try to hide away `rg` and shows error messages from it which are actually quite friendly when you mess up your regex. You can gradually learn `rg` flags or use existing knowledge from running it in the CLI. You can even input the `--help` flag to see the full `rg` help. Grug like!
3. *reuse muscle memory.* Does not try to block any type of buffer edits, such as deleting lines, etc. It's very easy to get such things wrong and when you do, Grug becomes unable to modify text in the middle of writing a large regex. Grug mad!! Only ensures graceful recovery in order to preserve basic UI integrity (possible due to the magic of extmarks). Recovery should be simple undo away. 
4. *uniformity.* only uses one tool, `rg`, and does not combine with other tools like `sed`. One should not have to worry about compatibility differences when writing regexes. Additionally it opens the door to use many fancy `rg` flags such as different regex engine that would not be possible in a mixed environment. Replacement is achieved by running `rg --replace=... --passthrough` on each file with configurable number of parallel workers.


## ⚡️ Requirements

- Neovim >= **0.9.5** (might work with lower versions)
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
        ... there are no required options atm...
      });
    end
  },

```

## ⚙️ Configuration

**grug-far.nvim** comes with the following:
- [default options][opts] 
- [highlights][highlights]

**Note on the key mappings**: By default, grug-far, will use `<localleader>` for it's keymaps as that is the vim
recommended way for plugins. See https://learnvimscriptthehardway.stevelosh.com/chapters/11.html#local-leader

So to use that, make sure you have `<localleader>` configured. For example, to use `,` as the local leader:
```
vim.g.maplocalleader = ','
```

## 🚀 Usage

### Opening and editing
You can open a new *grug-far.nvim* vertical split buffer with the `:GrugFar` command. But possibly
best to map a keybind to it for easy triggering.
Since it's *just a buffer*, you can edit in it as you see fit. The UI will try to guide
you along and recover gracefully if you do things like `ggVGd` (delete all lines).
Ultimately it leaves the power in your hands, and in any case recovery is just a few `u` taps away.

You can create multiple such buffers with potentially different searches, which will reflect in each buffer's title (configurable). 
The buffers should be visible in the buffers list if you need to toggle to them.

### Searching and replacing
Search and replace is accomplished by simply typing text on appropriately marked lines. Search will
happen in a debounced manner as you type. In the options, you can also specify a minimum number of characters
that one has to enter before search is triggered.
You can also specify a files filter to narrow down your search and more ripgrep flags to refine it further.
Error messages from ripgrep when entering invalid flags and so on are displayed to guide you along. 

_Note:_ When replacing matches with the empty string, you will be prompted to confirm, as the change is not
visible in the results area due to UI considering it just a search. If you
would like to see the actual replacement in the results area, add `--replace=` to the flags.

### Syncing results lines back to originating files
It is possible to sync the text of the lines in the results area back to their originating files.
This operation is either done on the current cursor line (`Sync Line`), or on all lines (`Sync All`). 

A sync will happen only if a line has changed in some way compared to the source file, so if there's 
either a replacement taking place or you have manually edited it.

Deleting result lines will cause them to be excluded from being synced by `Sync All` action.
This can be a nice way to refine a replacement in some situations if you want to exclude a particular file
or some particular matches.

If you don't edit the results list, `Sync All` and `Replace` have equivalent outcomes, except for one case. 
When you do multi-line replace with `--multiline` and `--multiline-dot-all` flags, sync won't work so you 
have to use replace. Essentially the difference it that `Replace` runs `rg --replace=... --passthrough` on 
each file and does not depend at all on what's in the results area. `Sync All` does a line by line
sync based on what's in the results area.

_Note:_ changing the `<line-number>:<column>:` prefix of result lines will disable sync for that line

_Note:_ sync is disabled when doing multiline replacement (`--multiline` flag)

_Note:_ if you would like sync to work when doing a replacement with empty string, please add `--replace=`
to the flags.

### Going to / Opening Location for match under cursor
When the cursor is placed on a result file path, you can go to that file by pressing `<enter>` in normal mode (`Goto` action default keybind).
When it's placed over a result match line, you will be taken to the file/line/column of the match. By default, the file buffer
is opened in the last window you were in before opening grug-far, which is typically the other vertical split.

If you would like to do the same thing, but have the cursor stay in place, you can use the `Open` action instead.

### Opening result lines in quickfix list

Result lines can be opened in the quickfix list. Deleting result lines will cause them not to be included. 

_Note:_ changing the `<line-number>:<column>:` prefix of result lines will remove lines from consideration

_Note:_ quickfix list is disabled when doing multiline replacement (`--multiline` flag)

### History

**grug-far** can keep track of your search history. This is done either by manually adding a history entry with
`History Add` action or automatically on certain successful actions like `Replace` and `Sync All`.

When you would like to pick one of your history entries to reuse, you can use the `History Open` action to
open the search history as a buffer. From there you can pick an entry that will be auto-filled in.

Note that you can edit the history buffer and save just like any other buffer if you need to do some cleanup.
The format of a history entry is:
```
<optional comment, ex: My special search>
Search: <text>
Replace: <text>
Files Filter: <text>
Flags: <text>
```
History entries are separated by one or more empty lines.

_Note_: **grug-far** will ignore lines that do not start with the prefixes above

### Seeing the full rg search command
Sometimes, mostly for debug purposes, it's useful to see the full `rg` command that gets executed on search. You
can toggle that on with the `Toggle Show rg Command` action, and the command will appear as the first thing in the
search results area.

The command is shell-escaped, so you can copy and execute it in a shell manually if you need to.

### Aborting
If you inadvertently launched a wrong search/sync/replace, you can abort early using the `Abort` action.

### Closing
When you are done, it is recommended to close the buffer with the configured keybinding 
(see Configuration section above) or just `:bd` in order to save on resources as some search results
can be quite beefy in size. The advantage of using the `Close` action as opposed to just `:bd` is that it
will ask you to confirm if there is a replace/sync in progress, as those would be aborted.

### Filetype
Note that *grug-far.nvim* buffers will have `filetype=grug-far`, history buffers will have `filetype=grug-far-history` and help will have `filetype=grug-far-help` if you need filter/exclude them in any situations.
Excluding seems to be necessary with copilot at the time of writing this.

### ⚒️  Lua API

For more control, you can programmatically open a grug-far buffer like so:
```sh
require('grug-far').grug_far(opts)
```
or if you would like to pre-fill current visual selection as the search text:
(note, this will also set `--fixed-strings` flag as selection can contain special characters)
```
require('grug-far').with_visual_selection(opts)
```

where `opts` will be merged with and override the global plugin options configured at setup time.

See here for all the available [options][opts] 

For more details on the API, see [docs][docs]

### 🥪 Cookbook

#### Launch with the current word under the cursor as the search string
```lua
:lua require('grug-far').grug_far({ prefills = { search = vim.fn.expand("<cword>") } })
```

#### Launch with the current file as a flag, which limits search/replace to it
```lua
:lua require('grug-far').grug_far({ prefills = { flags = vim.fn.expand("%") } })
```

#### Launch with the current visual selection, searching only current file
```lua
:<C-u>lua require('grug-far').with_visual_selection({ prefills = { flags = vim.fn.expand("%") } })
```

#### Toggle visibility of a particular instance and set title to a fixed string
```lua
:lua require('grug-far').toggle_instance({ instanceName="far", staticTitle="Find and Replace" })
```

#### Create a buffer local keybinding to toggle --fixed-strings flag
```lua
vim.api.nvim_create_autocmd('FileType', {
  group = augroup('test'),
  pattern = { 'grug-far' },
  callback = function()
    vim.keymap.set('n', '<localleader>w', function()
      local state = unpack(require('grug-far').toggle_flags({ '--fixed-strings' }))
      vim.notify('grug-far: toggled --fixed-strings ' .. (state and 'ON' or 'OFF'))
    end, { buffer = true })
  end,
})
```

## 📦 Similar Plugins / Inspiration

- [nvim-spectre][spectre]: the OG find and replace in a buffer plugin, great inspiration!
- [telescope.nvim][telescope]: lifted `rg` healthcheck from there :P
- [lazy.nvim][lazy]: used their beautiful `README.md` as a template
- [plugin-template.nvim][neovim-plugin-template]: super handy template, this plugin is based on it! 

[opts]: lua/grug-far/opts.lua
[docs]: doc/grug-far.txt
[highlights]: lua/grug-far/highlights.lua
[lazy]: https://github.com/folke/lazy.nvim
[spectre]: https://github.com/nvim-pack/nvim-spectre
[telescope]: https://github.com/nvim-telescope/telescope.nvim
[blacklistedReplaceFlags]: lua/grug-far/rg/blacklistedReplaceFlags.lua 
[neovim-plugin-template]: https://github.com/m00qek/plugin-template.nvim/tree/main
