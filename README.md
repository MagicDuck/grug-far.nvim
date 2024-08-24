# grug-far.nvim

**F**ind **A**nd **R**eplace plugin for neovim

<img width="500" alt="image" src="https://github.com/MagicDuck/grug-far.nvim/assets/95201/770900e2-36c6-488c-9117-5fcb514454cb">

Grug find! Grug replace! Grug happy!

## ✨ Features

- Search using the **full power** of `rg` or `ast-grep`
- Replace using almost the **full power** of `rg` or `ast-grep`. For example, for `rg`, some flags such as `--binary` and `--json`, etc. are [blacklisted][blacklistedReplaceFlags] in order to prevent unexpected output. The UI will warn you and prevent replace when using such flags.
- Automatic debounced search or manual search on leaving insert mode (and normal mode changes)
- Open search results in quickfix list
- Goto file/line/column of match when pressing `<Enter>` in normal mode on lines in the results output (keybind configurable).
- Inline edit result lines and sync them back to their originating file locations using a configurable keybinding.
- Manual/auto-save search history and reload
- Syntax highlighted search results
- Search results folding
- Multiline search & replace
- "Preview" result source while "scrolling" through results 

#### Searching:
<img width="1259" alt="image" src="https://github.com/user-attachments/assets/a0ff931b-8e73-4828-b0fd-b9fea94124d0">

#### Replacing:
<img width="1255" alt="image" src="https://github.com/user-attachments/assets/d348753a-e71d-4f28-bd4a-b99162de6537">

<details>
<summary>More screenshots:</summary>

#### Rg teaching you its ways
<img width="1258" alt="image" src="https://github.com/user-attachments/assets/ad95f913-1029-47de-b43c-7607bda60878">

#### Help:
<img width="1259" alt="image" src="https://github.com/user-attachments/assets/86231d5e-1f48-487b-97e0-a4059b6c2a47">

#### History:
<img width="1252" alt="image" src="https://github.com/user-attachments/assets/ee96bea6-62bc-4c39-b924-e5d42e70196a">

#### Ast-grep multiline search and replace:
<img width="1254" alt="image" src="https://github.com/user-attachments/assets/b15bbe33-cb27-4b8e-8b9d-241b64218fdc">

#### Ast-grep debug-query
<img width="1254" alt="image" src="https://github.com/user-attachments/assets/60ab0161-4da8-45ee-9d6e-6e23251a857b">

</details>

## 🤔 Philosophy

1. *strives for reduced mental overhead.* All actions you can take and as much help as possible is in your face (some configurable). Grug often forget how to do capture groups or which flag does what.
2. *transparency.* Does not try to hide away the underlying tool. For instance, error messages from `rg` are shown as they are actually quite friendly when you mess up your regex. You can gradually learn `rg` or `ast-grep` flags or use existing knowledge from running it in the CLI. You can even input the `--help` flag to see the full `rg` help or the `--debug-query=ast` flag to debug your `ast-grep` query. Grug like!
3. *reuse muscle memory.* Does not try to block any type of buffer edits, such as deleting lines, etc. It's very easy to get such things wrong and when you do, Grug becomes unable to modify text in the middle of writing a large regex. Grug mad!! Only ensures graceful recovery in order to preserve basic UI integrity (possible due to the magic of extmarks). Recovery should be simple undo away. 
4. *uniformity.* only uses one tool for both search and applying replace to keep things consistent. For example, does not combine `rg` with other tools like `sed`, even though `rg` does not support replacement directly. One should not have to worry about compatibility differences when writing regexes. Additionally it opens the door to use many fancy `rg` flags such as different regex engine that would not be possible in a mixed environment. There is currently one small exception for this due to the fact that `ast-grep` does not currently support something like a `--glob` flag, so we have to filter files through `rg`, but hopefully that can be rectified in the future.

## ⚡️ Requirements

- Neovim >= **0.10.0**
- [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep) >= 14 recommended
- a [Nerd Font](https://www.nerdfonts.com/) **_(optional)_**
- [ast-grep](https://ast-grep.github.io) **_(optional)_** if you would like to use the `ast-grep` search engine. Version >= `0.25.7` if you would like context lines flags to work.

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
        ... engine = 'ripgrep' is default, but 'astgrep' can be specified...
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
You can open a new *grug-far.nvim* vertical split buffer with the `:GrugFar` command.
Note that command supports the typical `command-modifiers` like `botright`, `aboveleft`, etc. and visual ranges.
In visual mode, the command will pre-fill the search string with the current visual selection.
Possibly best to map a keybind to it for easy triggering.
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

_Note:_ sync is only supported by `ripgrep` engine. The following explanation is `ripgrep` engine specific:

If you don't edit the results list, `Sync All` and `Replace` have equivalent outcomes, except for one case. 
When you do multi-line replace with `--multiline` and `--multiline-dot-all` flags, sync won't work so you 
have to use replace. Essentially the difference it that `Replace` runs `rg --replace=... --passthrough` on 
each file and does not depend at all on what's in the results area. `Sync All` does a line by line
sync based on what's in the results area.

_Note:_ changing the `<line-number>:<column>:` prefix of result lines will disable sync for that line

_Note:_ sync is disabled when doing multiline replacement (`--multiline` flag)

_Note:_ if you would like sync to work when doing a replacement with empty string, please add `--replace=`
to the flags.

### Going to / Opening Result Location 
When the cursor is placed on a result file path, you can go to that file by pressing `<enter>` in normal mode (`Goto` action default keybind).
When it's placed over a result match line, you will be taken to the file/line/column of the match. By default, the file buffer
is opened in the last window you were in before opening grug-far, which is typically the other vertical split.

If you would like to do the same thing, but have the cursor stay in place, you can use the `Open` action instead.

_Note:_ for both `Goto` and `Open` actions, if a `<count>` is entered beforehand, the location corresponding to `<count>` result line is used instead of the current cursor line. You can set the option `resultLocation.showNumberLabel = true` if you would like to have a visual indication of the `<count>`.

In order to smoothly `Open` each result location in sequence, you can use the `Open Next` and `Open Prev` actions.

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
Engine: <astgrep|ripgrep>
Search: <text>
Replace: <text>
Files Filter: <text>
Flags: <text>
```
where `<text>` can span multiple line with the aid of a "continuation prefix" (`| `). ex:
```
Replace: something
| additional replace text
| more replace text
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

### Swapping search engine
You can swap search engines with the `Swap Engine` action. Currently `ripgrep` (default) and `astgrep` are supported. 

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
If the above is called while in visual mode, it will pre-fill current visual selection as search text.
(note, this will also set `--fixed-strings` flag as selection can contain special characters)

Note that if you want to pre-fill current visual selection from command mode, you would have to use: 
```
:lua require('grug-far').with_visual_selection(opts)
```

where `opts` will be merged with and override the global plugin options configured at setup time.

See here for all the available [options][opts] 

For more API, see [docs][docs]

### 🥪 Cookbook

#### Launch with the current word under the cursor as the search string
```lua
:lua require('grug-far').grug_far({ prefills = { search = vim.fn.expand("<cword>") } })
```

#### Launch with ast-grep engine
```lua
:lua require('grug-far').grug_far({ engine = 'astgrep' })
```

#### Launch as a transient buffer which is both unlisted and fully deletes itself when not in use
```lua
:lua require('grug-far').grug_far({ transient = true })
```

#### Launch, limiting search/replace to current file
```lua
:lua require('grug-far').grug_far({ prefills = { paths = vim.fn.expand("%") } })
```

#### Launch with the current visual selection, searching only current file
```lua
:<C-u>lua require('grug-far').with_visual_selection({ prefills = { paths = vim.fn.expand("%") } })
```

#### Toggle visibility of a particular instance and set title to a fixed string
```lua
:lua require('grug-far').toggle_instance({ instanceName="far", staticTitle="Find and Replace" })
```

#### Create a buffer local keybinding to toggle --fixed-strings flag
```lua
vim.api.nvim_create_autocmd('FileType', {
  group =  vim.api.nvim_create_augroup('my-grug-far-custom-keybinds', { clear = true }),
  pattern = { 'grug-far' },
  callback = function()
    vim.keymap.set('n', '<localleader>w', function()
      local state = unpack(require('grug-far').toggle_flags({ '--fixed-strings' }))
      vim.notify('grug-far: toggled --fixed-strings ' .. (state and 'ON' or 'OFF'))
    end, { buffer = true })
  end,
})
```

#### Add nvim-tree integration to open search limited to focused directory or file

Create nvim-tree hotkey `z` that will create/open named instance `tree` of grug-far with the current directory of the file or directory in focus. On the second trigger, path of the `tree` grug-far instance will be updates, leaving other fields intact

<details>
<summary>Nvim tree lazy plugin setup</summary>

```lua
return {
  "nvim-tree/nvim-tree.lua",
  dependencies = "nvim-tree/nvim-web-devicons",
  config = function()
    local nvimtree = require("nvim-tree")

    -- custom on attach function to remove some default mappings and add custom ones
    local function my_on_attach(bufnr)
      local api = require("nvim-tree.api")
      local lib = require("nvim-tree.lib")

      local function opts(desc)
        return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
      end

      -- defaults
      api.config.mappings.default_on_attach(bufnr)

      -- add custom key mapping to search in directory with grug-far
      vim.keymap.set("n", "z", function()
        local node = lib.get_node_at_cursor()
        local grugFar = require("grug-far")
        if node then
          -- get directory of current file if it's a file
          local path
          if node.type == "directory" then
            -- Keep the full path for directories
            path = node.absolute_path
          else
            -- Get the directory of the file
            path = vim.fn.fnamemodify(node.absolute_path, ":h")
          end

          -- escape all spaces in the path with "\ "
          path = path:gsub(" ", "\\ ")

          local prefills = {
            paths = path,
          }

          -- instance check
          if not grugFar.has_instance("tree") then
            grugFar.grug_far({
              instanceName = "tree",
              prefills = prefills,
              staticTitle = "Find and Replace from Tree",
            })
          else
            grugFar.open_instance("tree")
            -- updating the prefills without clearing the search and other fields
            grugFar.update_instance_prefills("tree", prefills, false)
          end
        end
      end, opts("Search in directory"))
    end

    -- https://github.com/nvim-tree/nvim-tree.lua/blob/master/lua/nvim-tree.lua#L342
    nvimtree.setup({
      on_attach = my_on_attach,
      -- rest of your config
    })
  end,
}
```
</details>
Small video of it in action: https://github.com/MagicDuck/grug-far.nvim/issues/165#issuecomment-2257439367

## ❓ Q&A

#### 1. Getting RPC[Error] ... Document for URI could not be found: file:///.../Grug%20FAR%20-%20...
Chances are that you are using copilot.nvim and the fix is to exclude `grug-far` file types in copilot config:
```lua
filetypes = {
  ["grug-far"] = false,
  ["grug-far-history"] = false,
  ["grug-far-help"] = false,
}
```

#### 2. Why do folds not appear when using which-key plugin?
This is a known issue in which-key v3. See https://github.com/folke/which-key.nvim/issues/830
The workaround is to exclude main `grug-far` filetype in which-key plugin config:
```lua
disable = {
  ft = { 'grug-far' },
},
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
[blacklistedReplaceFlags]: lua/grug-far/engine/ripgrep/blacklistedReplaceFlags.lua 
[neovim-plugin-template]: https://github.com/m00qek/plugin-template.nvim/tree/main
