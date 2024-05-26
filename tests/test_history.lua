local MiniTest = require('mini.test')
local helpers = require('grug-far/test/helpers')
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

T['can manually save and reload from history'] = function()
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
    prefills = { search = 'grug', flags = '-i' },
  })
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys(100, '<esc>cc', 'walks')
  vim.loop.sleep(100)
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys(100, '<esc>cc', 'talks')
  vim.loop.sleep(100)
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys('<esc>' .. keymaps.historyOpen.n)
  helpers.childWaitForScreenshotText(child, 'History')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys(100, '<esc>16G', '<enter>')
  vim.loop.sleep(100)
  helpers.childExpectScreenshot(child)
end

T['auto-saves to history on replace'] = function()
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

  vim.loop.sleep(50)
  child.type_keys('<esc>' .. keymaps.historyOpen.n)
  helpers.childWaitForScreenshotText(child, 'History')
  helpers.childExpectScreenshot(child)
end

T['auto-saves to history on sync all'] = function()
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

  vim.loop.sleep(50)
  child.type_keys('<esc>' .. keymaps.historyOpen.n)
  helpers.childWaitForScreenshotText(child, 'History')
  helpers.childExpectScreenshot(child)
end

T['dedupes last history entry'] = function()
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
    prefills = { search = 'grug', replacement = 'curly', flags = '-i' },
  })
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys('<esc>' .. keymaps.historyOpen.n)
  helpers.childWaitForScreenshotText(child, 'History')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

return T
