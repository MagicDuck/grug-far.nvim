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
    { filename = 'file1.txt', content = [[ grug walks ]] },
    {
      filename = 'file2.doc',
      content = [[ 
      grug talks and grug drinks
      then grug thinks
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'return match .. "_and_curly"' },
    replacementInterpreter = 'vimscript',
  })

  helpers.childWaitForFinishedStatus(child)

  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['can search within line range with replace interpreter'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file1.txt',
      content = [[ 
      grug talks and grug drinks
      then grug thinks
      and grug is confused!
    ]],
    },
  })

  helpers.cdTempTestDir(child)
  child.cmd('e file1.txt')
  child.type_keys(10, 'ggjVj')
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'return match .. "_and_curly"' },
    replacementInterpreter = 'vimscript',
    visualSelectionUsage = 'operate-within-range',
  })

  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['search can report eval error from replace interpreter'] = function()
  helpers.writeTestFiles({
    { filename = 'file1.txt', content = [[ grug walks ]] },
    {
      filename = 'file2.doc',
      content = [[ 
      grug talks and grug drinks
      then grug thinks
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'return non_existent_one .. "_and_curly"' },
    replacementInterpreter = 'vimscript',
  })
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace with replace interpreter'] = function()
  helpers.writeTestFiles({
    { filename = 'file1.txt', content = [[ grug walks ]] },
    {
      filename = 'file2.doc',
      content = [[ 
      grug talks and grug drinks
      then grug thinks
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'return match .. "_and_curly"' },
    replacementInterpreter = 'vimscript',
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'grug_and_curly talks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['replace can report eval error from replace interpreter'] = function()
  helpers.writeTestFiles({
    { filename = 'file1.txt', content = [[ grug walks ]] },
    {
      filename = 'file2.doc',
      content = [[ 
      grug talks and grug drinks
      then grug thinks
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'return non_existent_one .. "_and_curly"' },
    replacementInterpreter = 'vimscript',
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace failed!')
  helpers.childExpectScreenshot(child)
end

return T
