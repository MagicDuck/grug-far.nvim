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

T['can search with replace interpreter'] = function()
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
    prefills = { search = 'grug.$A', replacement = 'return match .. "_" .. vars.A' },
    replacementInterpreter = 'lua',
  })

  helpers.childWaitForFinishedStatus(child)

  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['can search within line range with replace interpreter'] = function()
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
  child.type_keys(10, 'ggjV')
  helpers.childRunGrugFar(child, {
    engine = 'astgrep',
    prefills = { search = 'grug', replacement = 'return match .. "_and_curly"' },
    replacementInterpreter = 'lua',
    visualSelectionUsage = 'operate-within-range',
  })

  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can search with replace interpreter and file filter'] = function()
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
    prefills = {
      search = 'grug.$A',
      replacement = 'return match .. "_" .. vars.A',
      filesFilter = '**/*.ts',
    },
    replacementInterpreter = 'lua',
  })

  helpers.childWaitForFinishedStatus(child)

  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['search can report eval error from replace interpreter'] = function()
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
    prefills = {
      search = 'grug.$A',
      replacement = 'return non_existent_one .. "_" .. vars.A',
    },
    replacementInterpreter = 'lua',
  })

  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['search can report eval error from replace interpreter with files filter'] = function()
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
    prefills = {
      search = 'grug.$A',
      replacement = 'return non_existent_one .. "_" .. vars.A',
      filesFilter = '**/*.ts',
    },
    replacementInterpreter = 'lua',
  })

  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace with replace interpreter'] = function()
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
    prefills = {
      search = 'grug.$A',
      replacement = 'return match .. "_" .. vars.A',
    },
    replacementInterpreter = 'lua',
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>cc', '$A')
  helpers.childWaitForScreenshotText(child, 'grug.walks_walks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace with replace interpreter and file filter'] = function()
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
    prefills = {
      search = 'grug.$A',
      replacement = 'return match .. "_" .. vars.A',
      filesFilter = '**/*.ts',
    },
    replacementInterpreter = 'lua',
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>cc', '$A')
  helpers.childWaitForScreenshotText(child, 'grug.walks_walks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['replace can report eval error from replace interpreter'] = function()
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
    prefills = { search = 'grug.$A', replacement = 'return non_existent_one .. "_" .. vars.A' },
    replacementInterpreter = 'lua',
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace failed!')
  helpers.childExpectScreenshot(child)
end

T['replace can report eval error from replace interpreter with files filter'] = function()
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
    prefills = {
      search = 'grug.$A',
      replacement = 'return non_existent_one .. "_" .. vars.A',
      filesFilter = '**/*.ts',
    },
    replacementInterpreter = 'lua',
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace failed!')
  helpers.childExpectScreenshot(child)
end

T['can replace with replace interpreter within buf range'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file2.ts',
      content = [[ 
    if (grug.thinks || talks) {
      grug.walks(talks)
    }
    ]],
    },
  })

  helpers.cdTempTestDir(child)
  child.cmd('e file2.ts')
  child.type_keys(10, 'ggjjV')
  helpers.childRunGrugFar(child, {
    engine = 'astgrep',
    prefills = {
      search = 'grug.$A',
      replacement = 'return match .. "_" .. vars.A',
    },
    replacementInterpreter = 'lua',
    visualSelectionUsage = 'operate-within-range',
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>cc', '$A')
  helpers.childWaitForScreenshotText(child, 'grug.walks_walks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

return T
