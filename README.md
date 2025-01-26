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
- Replace using lua interpreted replacement for each match

#### Searching:
<img width="1263" alt="image" src="https://github.com/user-attachments/assets/7851bc37-bd88-473d-a09a-1510088e074c" />

#### Replacing:
<img width="1260" alt="image" src="https://github.com/user-attachments/assets/c8edd521-9321-4e83-a4ce-e3d98ac1b346" />

<details>
<summary>More screenshots:</summary>

#### Rg teaching you its ways
<img width="1258" alt="image" src="https://github.com/user-attachments/assets/c59da414-2836-4e1c-93cd-9ac4568c819c">

#### Help:
<img width="1252" alt="image" src="https://github.com/user-attachments/assets/5da63e72-f768-46e7-a807-b26c6f44c42c">

#### History:
<img width="1252" alt="image" src="https://github.com/user-attachments/assets/ee96bea6-62bc-4c39-b924-e5d42e70196a">

#### Ast-grep multiline search and replace:
<img width="1254" alt="image" src="https://github.com/user-attachments/assets/1f07c536-ef41-476f-9a15-7f0715c0579c" />

#### Ast-grep debug-query
<img width="1251" alt="image" src="https://github.com/user-attachments/assets/20fab223-56b6-42ff-825b-0df3c0e8d625">

#### Ripgrep with lua interpreted replacement
<img width="1259" alt="image" src="https://github.com/user-attachments/assets/e2b9ca48-e0cc-49d1-b048-5042f40b774b" />

#### Astgrep with vimscript interpreted replacement
<img width="1257" alt="image" src="https://github.com/user-attachments/assets/34eebeda-4e29-4fed-a751-eac3f879425c" />



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
- [ast-grep](https://ast-grep.github.io) **_(optional)_** if you would like to use the `ast-grep` search engine. Version >= `0.25.7` if you would like context lines flags to work. Version >= `0.28.0` recommended for better performance as it has builtin `--globs` support.
- either [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) or [mini.icons](https://github.com/echasnovski/mini.icons) for file icons support **_(optional)_**

Run `:checkhealth grug-far` if you see unexpected issues.

## 📦 Installation

Using [lazy.nvim][lazy]:
```lua
  {
    'MagicDuck/grug-far.nvim',
    config = function()
      require('grug-far').setup({
        -- options, see Configuration section below
        -- there are no required options atm
        -- engine = 'ripgrep' is default, but 'astgrep' can be specified
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

### Replacing each match with the result of an interpreted script

Some situations require the power of arbitrary code executed for each search to determine the proper replacements.
In those cases, you can use the `Swap Replacement Interpreter` action to switch to a desired replacement interpreter,
such as `lua` or `vimscript`.
For example with the `lua` interpreter, this will allow you to write multi-line lua code, essentially the body of a lua function,
in the `Replace:` input.

You can use `match` to refer to each match and need to `return` the value you want to be the replacement.
In the case of the `astgrep` engine, you will also have access to the meta variables by accessing them through the
`vars` table. e.g. `$A` is referred to by `vars.A`, `$$$ARGS` is referred to by `vars.ARGS`.

It is a similar situation for the `vimscript` interpreter. 

### Syncing results lines back to originating files

It is possible to sync the text of the lines in the results area back to their originating files.
There are 3 types of actions that can accomplish this operation:
1. `Sync Line` - syncs current line
2. `Sync All` - syncs all lines
3. `Apply Next`/`Apply Prev` - syncs current line/diff and smartly deletes it from the result buffer

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

### Going to / Opening / Previewing Result Location
When the cursor is placed on a result file path, you can go to that file by pressing `<enter>` in normal mode (`Goto` action default keybind).
When it's placed over a result match line, you will be taken to the file/line/column of the match. By default, the file buffer
is opened in the last window you were in before opening grug-far, which is typically the other vertical split.

If you would like to do the same thing, but have the cursor stay in place, you can use the `Open` action instead.

_Note:_ for both `Goto` and `Open` actions, if a `<count>` is entered beforehand, the location corresponding to `<count>` result line is used instead of the current cursor line. You can set the option `resultLocation.showNumberLabel = true` if you would like to have a visual indication of the `<count>`.

In order to smoothly `Open` each result location in sequence, you can use the `Open Next` and `Open Prev` actions.

If you would like to keep the buffers layout, you can use the `Preview` action instead, which will open location in a floating window.

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
<optional comment, e.g. My special search>
Engine: <astgrep|ripgrep>(|lua)?
Search: <text>
Replace: <text>
Files Filter: <text>
Flags: <text>
```
where `<text>` can span multiple line with the aid of a "continuation prefix" (`| `). e.g.
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
require('grug-far').open(opts)
```
If the above is called while in visual mode, it will pre-fill current visual selection as search text.
(note, this will also set `--fixed-strings` flag as selection can contain special characters)

Note that if you want to pre-fill current visual selection from command mode, you would have to use: 
```
:lua require('grug-far').with_visual_selection(opts)
```
(command mode is the only case where this is necessary in order to force using the visual selection)

where `opts` will be merged with and override the global plugin options configured at setup time.

See here for all the available [options][opts] 

For more API, see [docs][docs]

### 🥪 Cookbook

#### Launch with the current word under the cursor as the search string
```lua
:lua require('grug-far').open({ prefills = { search = vim.fn.expand("<cword>") } })
```

#### Launch with ast-grep engine
```lua
:lua require('grug-far').open({ engine = 'astgrep' })
```

#### Launch as a transient buffer which is both unlisted and fully deletes itself when not in use
```lua
:lua require('grug-far').open({ transient = true })
```

#### Launch, limiting search/replace to current file
```lua
:lua require('grug-far').open({ prefills = { paths = vim.fn.expand("%") } })
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

#### Create a buffer local keybinding to open a result location and immediately close grug-far.nvim
```lua
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('grug-far-keybindings', { clear = true }),
  pattern = { 'grug-far' },
  callback = function()
    vim.api.nvim_buf_set_keymap(0, 'n', '<C-enter>', '<localleader>o<localleader>c', {})
  end,
})
```
(where `<localleader>o` and `<localleader>c` are the default keybindings for Open and Close actions. You will need to change them if you set them to something different)

#### Create a buffer local keybinding to jump back to Search input
``` lua
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('grug-far-keymap', { clear = true }),
  pattern = { 'grug-far' },
  callback = function()
    -- jump back to search input by hitting left arrow in normal mode:
    vim.keymap.set('n', '<left>', function()
      vim.api.nvim_win_set_cursor(vim.fn.bufwinid(0), { 2, 0 })
    end, { buffer = true })
  end,
})
```

#### Add neo-tree integration to open search limited to focused directory or file

Create a hotkey `z` in `neo-tree` that will create/open a named instance of grug-far with the current directory of the file or directory in focus. On the second trigger, path of the grug-far instance will be updated, leaving other fields intact.

<details>
<summary>Neo tree lazy plugin setup</summary>

Small video of it in action: https://github.com/MagicDuck/grug-far.nvim/issues/165#issuecomment-2257439367

```lua
return {
  "nvim-neo-tree/neo-tree.nvim",
  dependencies = "nvim-tree/nvim-web-devicons",
  config = function()
    local function open_grug_far(prefills)
      local grug_far = require("grug-far")

      if not grug_far.has_instance("explorer") then
        grug_far.open({ instanceName = "explorer" })
      else
        grug_far.open_instance("explorer")
      end
      -- doing it seperately because multiple paths doesn't open work when passed with open
      -- updating the prefills without clearing the search and other fields
      grug_far.update_instance_prefills("explorer", prefills, false)
    end
    require("neo-tree").setup {
      commands = {
        -- create a new neo-tree command
        grug_far_replace = function(state)
          local node = state.tree:get_node()
          local prefills = {
            -- also escape the paths if space is there
            -- if you want files to be selected, use ':p' only, see filename-modifiers
            paths = node.type == "directory" and vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":p"))
        or vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":h")),
          }
          open_grug_far(prefills)
        end,
        -- https://github.com/nvim-neo-tree/neo-tree.nvim/blob/fbb631e818f48591d0c3a590817003d36d0de691/doc/neo-tree.txt#L535
        grug_far_replace_visual = function(state, selected_nodes, callback)
          local paths = {}
          for _, node in pairs(selected_nodes) do
            -- also escape the paths if space is there
            -- if you want files to be selected, use ':p' only, see filename-modifiers
            local path = node.type == "directory" and vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":p"))
        or vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":h"))
            table.insert(paths, path)
          end
          local prefills = { paths = table.concat(paths, "\n") }
          open_grug_far(prefills)
        end,
      },
      window = {
        mappings = {
          -- map our new command to z
          z = "grug_far_replace",
        },
      },
      -- rest of your config
    }
  end,
}
```
</details>

#### Add oil.nvim integration to open search limited to focused directory

Create a hotkey `gs` in `oil.nvim` that will create/open a named instance of grug-far with the current directory in focus. On the second trigger, path of the grug-far instance will be updated, leaving other fields intact.

<details>
<summary>Oil explorer lazy plugin setup</summary>

```lua
return {
  "stevearc/oil.nvim",
  config = function()
    local oil = require "oil"
    oil.setup {
      keymaps = {
        -- create a new mapping, gs, to search and replace in the current directory
        gs = {
          callback = function()
            -- get the current directory
            local prefills = { paths = oil.get_current_dir() }

            local grug_far = require "grug-far"
            -- instance check
            if not grug_far.has_instance "explorer" then
              grug_far.open {
                instanceName = "explorer",
                prefills = prefills,
                staticTitle = "Find and Replace from Explorer",
              }
            else
              grug_far.open_instance "explorer"
              -- updating the prefills without clearing the search and other fields
              grug_far.update_instance_prefills("explorer", prefills, false)
            end
          end,
          desc = "oil: Search in directory",
        },
      },
      -- rest of your config
    }
  end,
}
```
</details>

#### Add mini.files integration to open search limited to focused directory

Create a hotkey `gs` in `mini.files` that will create/open a named instance of grug-far with the current directory in focus. On the second trigger, the path of the grug-far instance will be updated, leaving other fields intact.

<details>
<summary>MiniFiles explorer lazy plugin setup</summary>

```lua
return {
  "echasnovski/mini.files",
  config = function()
    local MiniFiles = require "mini.files"

    MiniFiles.setup({
      -- your config
    })

    
    local files_grug_far_replace = function(path)
      -- works only if cursor is on the valid file system entry
      local cur_entry_path = MiniFiles.get_fs_entry().path
      local prefills = { paths = vim.fs.dirname(cur_entry_path) }

      local grug_far = require "grug-far"

      -- instance check
      if not grug_far.has_instance "explorer" then
        grug_far.open {
          instanceName = "explorer",
          prefills = prefills,
          staticTitle = "Find and Replace from Explorer",
        }
      else
        grug_far.open_instance "explorer"
        -- updating the prefills without crealing the search and other fields
        grug_far.update_instance_prefills("explorer", prefills, false)
      end
    end

    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesBufferCreate",
      callback = function(args)
        vim.keymap.set("n", "gs", files_grug_far_replace, { buffer = args.data.buf_id, desc = "Search in directory" })
      end,
    })
  end,
}
```
</details>

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
