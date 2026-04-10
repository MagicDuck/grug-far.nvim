local MiniTest = require('mini.test')
local helpers = require('grug-far.test.helpers')
local keymaps = helpers.getKeymaps()

---@type NeovimChild
local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      helpers.initChildNeovim(child)
    end,
    -- Stop once all test cases are finished
    post_once = child.stop,
  },
})

T['can replace with replace string'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file2.ts',
      content = [[ 
    if (grug || talks) {
      grug.walks(talks)
    }
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    engine = 'astgrep',
    prefills = { search = 'grug', replacement = 'curly' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'curly.walks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace with file filter'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file2.ts',
      content = [[ 
    if (grug || talks) {
      grug.walks(talks)
    }
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    engine = 'astgrep',
    prefills = { search = 'grug', replacement = 'curly', filesFilter = '**/*.ts' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'curly.walks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace within one file'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file2.ts',
      content = [[ 
    if (grug || talks) {
      grug.walks(talks)
    }
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    engine = 'astgrep',
    prefills = { search = 'grug', replacement = 'curly', paths = './file2.ts' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'curly.walks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace within one dir'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file2.ts',
      content = [[ 
    if (grug || talks) {
      grug.walks(talks)
    }
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    engine = 'astgrep',
    prefills = { search = 'grug', replacement = 'curly', paths = './' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'curly.walks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace within one dir with spaces'] = function()
  helpers.writeTestFiles({
    {
      filename = 'foo bar/file2.ts',
      content = [[ 
    if (grug || talks) {
      grug.walks(talks)
    }
    ]],
    },
  }, { 'foo bar' })

  helpers.childRunGrugFar(child, {
    engine = 'astgrep',
    prefills = { search = 'grug', replacement = 'curly', paths = './foo\\ bar' },
  })
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, '(curly || talks)')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace within multiple dirs with spaces'] = function()
  helpers.writeTestFiles({
    {
      filename = 'hello world/file2.ts',
      content = [[ 
      if (grug || talks) {
        grug.walks(talks)
      }
    ]],
    },
  }, { 'foo bar', 'hello world' })

  helpers.childRunGrugFar(child, {
    engine = 'astgrep',
    prefills = { search = 'grug', replacement = 'curly', paths = './foo\\ bar ./hello\\ world' },
  })
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, '(curly || talks)')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace with empty string'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file2.ts',
      content = [[ 
    if (grug || talks) {
      grug.walks(talks)
    }
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    engine = 'astgrep',
    prefills = { search = 'grug', flags = '--rewrite=' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>cc', 'talks')
  helpers.childWaitForScreenshotText(child, '( || talks)')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['is prevented from replacing with blacklisted flags'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file2.ts',
      content = [[ 
    if (grug || talks) {
      grug.walks(talks)
    }
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    engine = 'astgrep',
    prefills = { search = 'grug', replace = 'curly', flags = '--json' },
  })

  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)

  helpers.childWaitForScreenshotText(child, 'replace cannot work')
  helpers.childWaitForScreenshotText(child, 'error: the argument')
  helpers.childExpectScreenshot(child)
end

T['can replace within buffer range'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file2.ts',
      content = [[ 
    if (grug || talks) {
      grug.walks(talks)
    }
    ]],
    },
  })

  helpers.cdTempTestDir(child)
  child.cmd('e file2.ts')
  child.type_keys(10, 'ggjwwwwvj$')
  helpers.childRunGrugFar(child, {
    engine = 'astgrep',
    prefills = { search = 'grug', replacement = 'bruv' },
    visualSelectionUsage = 'operate-within-range',
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>cc', 'bruv')
  helpers.childWaitForScreenshotText(child, 'bruv.walks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can run hooks.on_before_edit_file on replace'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file2.ts',
      content = [[ 
    if (grug || talks) {
      grug.walks(talks)
    }
    ]],
    },
  })

  helpers.cdTempTestDir(child)
  child.lua([[GrugFar.open({
    engine = 'astgrep',
    prefills = { search = 'grug', replacement = 'curly' },
    hooks = {
      on_before_edit_file = function(on_finish, file)
        local contents = 'grug from ON_BEFORE_EDIT_FILE\n'
        return require('grug-far').spawn_cmd_async({
          cmd_path = 'cat',
          args = { file.path },
          on_stdout_chunk = function(data) 
            contents = contents .. data
          end,
          on_finish = function(...)
            vim.fn.writefile(vim.split(contents, '\n'), file.path)
            on_finish(...)
          end
        })
      end,
    }
  })]])
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'curly from ON_BEFORE_EDIT_FILE')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can run failed hooks.on_before_edit_file on replace'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file2.ts',
      content = [[ 
    if (grug || talks) {
      grug.walks(talks)
    }
    ]],
    },
  })

  helpers.cdTempTestDir(child)
  child.lua([[GrugFar.open({
    engine = 'astgrep',
    prefills = { search = 'grug', replacement = 'curly' },
    hooks = {
      on_before_edit_file = function(on_finish, file)
        return require('grug-far').spawn_cmd_async({
          cmd_path = 'NON_EXISTENT_COMMAND',
          args = { file.path },
          on_finish = on_finish,
        })
      end,
    }
  })]])
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can run hooks.on_before_edit_file while replacing within buffer range'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file2.ts',
      content = [[ 
    if (grug || talks) {
      grug.walks(talks)
    }
    ]],
    },
  })

  helpers.cdTempTestDir(child)
  child.cmd('e file2.ts')
  child.type_keys(10, 'ggjwwwwvj$')
  helpers.childRunGrugFar(child, {
    engine = 'astgrep',
    prefills = { search = 'grug', replacement = 'bruv' },
    visualSelectionUsage = 'operate-within-range',
  })

  child.lua([[GrugFar.open({
    engine = 'astgrep',
    prefills = { search = 'grug', replacement = 'bruv' },
    visualSelectionUsage = 'operate-within-range',
    hooks = {
      on_before_edit_file = function(on_finish, file)
        return require('grug-far').spawn_cmd_async({
          cmd_path = 'cat',
          args = { file.path },
          on_finish = on_finish,
        })
      end,
    }
  })]])
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>cc', 'bruv')
  helpers.childWaitForScreenshotText(child, 'bruv.walks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can run failed hooks.on_before_edit_file while replacing within buffer range'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file2.ts',
      content = [[ 
    if (grug || talks) {
      grug.walks(talks)
    }
    ]],
    },
  })

  helpers.cdTempTestDir(child)
  child.cmd('e file2.ts')
  child.type_keys(10, 'ggjwwwwvj$')
  helpers.childRunGrugFar(child, {
    engine = 'astgrep',
    prefills = { search = 'grug', replacement = 'bruv' },
    visualSelectionUsage = 'operate-within-range',
  })

  child.lua([[GrugFar.open({
    engine = 'astgrep',
    prefills = { search = 'grug', replacement = 'bruv' },
    visualSelectionUsage = 'operate-within-range',
    hooks = {
      on_before_edit_file = function(on_finish, file)
        return require('grug-far').spawn_cmd_async({
          cmd_path = 'NON_EXISTENT_COMMAND',
          args = { file.path },
          on_finish = on_finish,
        })
      end,
    }
  })]])
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

return T
