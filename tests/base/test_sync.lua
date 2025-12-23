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

T['can sync all'] = function()
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

  child.type_keys('<esc>' .. keymaps.syncLocations.n)
  helpers.childWaitForUIVirtualText(child, 'sync completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'curly talks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can sync all with changes ignoring deleted lines'] = function()
  helpers.writeTestFiles({
    { filename = 'file1.txt', content = [[ 
       grug walks
       then grug swims
      ]] },
    {
      filename = 'file2.doc',
      content = [[ 
      grug talks and grug drinks
      then grug thinks
      and grug flies
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'curly' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys(10, '<esc>7G', 'dddd', 'j')
  child.type_keys(10, 'A', ' a deep depth indeed!')
  child.type_keys(10, '<esc>11G', 'dddd')
  child.type_keys(10, '$bi', 'believes he ')

  child.type_keys('<esc>' .. keymaps.syncLocations.n)

  helpers.childWaitForUIVirtualText(child, 'sync completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys(10, '<esc>1G', 'cc', 'curly')
  helpers.childWaitForScreenshotText(child, '3 matches in 2 files')
  helpers.childWaitForScreenshotText(child, 'a deep depth indeed')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['is prevented when multiline search'] = function()
  helpers.writeTestFiles({
    { filename = 'file1.txt', content = [[ 
       grug walks
       then grug swims
      ]] },
    {
      filename = 'file2.doc',
      content = [[ 
      grug talks and grug drinks
      then grug thinks
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', flags = '--multiline' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys(10, '<esc>7G', 'dd')
  child.type_keys(10, 'A', ' a deep depth indeed!')

  child.type_keys('<esc>' .. keymaps.syncLocations.n)

  helpers.childWaitForUIVirtualText(child, 'sync disabled')
  helpers.childExpectScreenshot(child)
end

T['can sync individual line'] = function()
  helpers.writeTestFiles({
    { filename = 'file1.txt', content = [[ 
       grug walks
       then grug swims
      ]] },
    {
      filename = 'file2.doc',
      content = [[ 
      grug talks and grug drinks
      then grug thinks
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys(10, '<esc>8G', 'A', ' a deep depth indeed!')
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.syncLine.n)

  helpers.childWaitForUIVirtualText(child, 'sync completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.refresh.n)
  helpers.childWaitForScreenshotNotContainingText(child, 'sync completed')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['can sync all within buffer range'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file1.txt',
      content = [[ 
      grug talks and grug drinks
      then grug thinks
      and grug flies
      but grug is confused
    ]],
    },
  })

  helpers.cdTempTestDir(child)
  child.cmd('e file1.txt')
  child.type_keys(10, 'ggjwwvjj$')
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'curly' },
    visualSelectionUsage = 'operate-within-range',
  })
  helpers.childWaitForFinishedStatus(child)

  child.cmd('set number')
  child.type_keys(10, '<esc>7G', 'dddd', 'j')
  child.type_keys(10, 'A', ' a deep depth indeed!')

  child.type_keys('<esc>' .. keymaps.syncLocations.n)

  helpers.childWaitForUIVirtualText(child, 'sync completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys(10, '<esc>1G', 'cc', 'curly')
  helpers.childWaitForScreenshotText(child, '2 matches in 1 files')
  helpers.childWaitForScreenshotText(child, 'a deep depth indeed')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['can sync file around line'] = function()
  helpers.writeTestFiles({
    { filename = 'file1.txt', content = [[ 
       grug walks
       then grug swims
      ]] },
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

  child.type_keys('<esc>8G0')
  child.type_keys(10, '<esc>' .. keymaps.syncFile.n)

  helpers.childWaitForScreenshotText(child, 'sync completed!')
  child.cmd('vsp | e file1.txt')
  helpers.childExpectScreenshot(child)
end

T['can sync file around line in second result file'] = function()
  helpers.writeTestFiles({
    { filename = 'file1.txt', content = [[ 
       grug walks
       then grug swims
      ]] },
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

  child.type_keys('<esc>13G0zz')
  child.type_keys(10, '<esc>' .. keymaps.syncFile.n)

  helpers.childWaitForScreenshotText(child, 'sync completed!')
  child.cmd('vsp | e file2.doc')
  helpers.childExpectScreenshot(child)
end

T['can sync next'] = function()
  helpers.writeTestFiles({
    { filename = 'file1.txt', content = [[ 
       grug walks
       then grug swims
      ]] },
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

  child.type_keys('<esc>8G0')
  child.type_keys(10, '<esc>' .. keymaps.syncNext.n)

  helpers.childWaitForScreenshotText(child, 'sync completed!')
  child.cmd('vsp | e file1.txt')
  helpers.childExpectScreenshot(child)
end

T['can sync prev'] = function()
  helpers.writeTestFiles({
    { filename = 'file1.txt', content = [[ 
       grug walks
       then grug swims
      ]] },
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

  child.type_keys('<esc>9G0')
  child.type_keys(10, '<esc>' .. keymaps.syncPrev.n)

  helpers.childWaitForScreenshotText(child, 'sync completed!')
  child.cmd('vsp | e file1.txt')
  helpers.childExpectScreenshot(child)
end

return T
