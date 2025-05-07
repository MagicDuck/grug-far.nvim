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
    prefills = { search = 'grug', replacement = 'curly' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'curly talks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace within one file'] = function()
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
    prefills = { search = 'grug', replacement = 'curly', paths = './file2.doc' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'curly talks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace within one dir'] = function()
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
    prefills = { search = 'grug', replacement = 'curly', paths = './' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'curly talks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace within one dir with spaces'] = function()
  helpers.writeTestFiles({
    { filename = 'foo bar/file1.txt', content = [[ grug walks ]] },
    {
      filename = 'foo bar/file2.doc',
      content = [[ 
      grug talks and grug drinks
      then grug thinks
    ]],
    },
  }, { 'foo bar' })

  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'curly', paths = './foo\\ bar' },
  })
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'curly talks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace within multiple dirs with spaces'] = function()
  helpers.writeTestFiles({
    { filename = 'foo bar/file1.txt', content = [[ grug walks ]] },
    {
      filename = 'hello world/file2.doc',
      content = [[ 
      grug talks and grug drinks
      then grug thinks
    ]],
    },
  }, { 'foo bar', 'hello world' })

  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'curly', paths = './foo\\ bar ./hello\\ world' },
  })
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'curly talks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace with empty string'] = function()
  helpers.writeTestFiles({
    { filename = 'file1.txt', content = [[ and grug walks ]] },
    {
      filename = 'file2.doc',
      content = [[ 
      grug talks and grug drinks
      and then grug thinks
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', flags = '--replace=' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>cc', 'drinks')
  helpers.childWaitForScreenshotText(child, '1 matches in 1 files')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['is prevented from replacing with blacklisted flags'] = function()
  helpers.writeTestFiles({
    { filename = 'file1', content = [[ grug walks ]] },
    {
      filename = 'file2',
      content = [[ 
      grug talks and grug drinks
      then grug thinks
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replace = 'curly', flags = '--count-matches' },
  })

  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)

  helpers.childWaitForScreenshotText(child, 'replace cannot work')
  helpers.childExpectScreenshot(child)
end

T['can replace with within buffer range'] = function()
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
  child.type_keys(10, 'ggjwwvj$')
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'curly' },
    visualSelectionUsage = 'operate-within-range',
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'curly drinks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

return T
