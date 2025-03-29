local MiniTest = require('mini.test')
local helpers = require('grug-far.test.helpers')
local opts = require('grug-far.opts')
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
      then grug thinks and talks
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', flags = '-i' },
  })
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys('<esc>cc', 'walks')
  helpers.childWaitForScreenshotText(child, '1 matches in 1 files')
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys('<esc>cc', 'talks')
  helpers.childWaitForScreenshotText(child, '2 matches in 1 files')
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys('<esc>' .. keymaps.historyOpen.n)
  helpers.childWaitForScreenshotText(child, 'History')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>24G', '<enter>')
  helpers.childWaitForScreenshotText(child, '4 matches in 2 files')
  helpers.childWaitForFinishedStatus(child)
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

  helpers.sleep(child, 50) -- make sure history entry gets added
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

  helpers.sleep(child, 50) -- make sure history entry gets added
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

  helpers.sleep(child, 50) -- make sure history entry gets added
  child.type_keys('<esc>' .. keymaps.historyOpen.n)
  helpers.childWaitForScreenshotText(child, 'History')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['replacement interpreter swaps when reloading from history'] = function()
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
    prefills = { search = 'grug', replacement = 'return "bob"' },
    replacementInterpreter = 'lua',
  })
  helpers.childWaitForFinishedStatus(child)
  helpers.childWaitForScreenshotText(child, '[lua]')
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys('<esc>cc', 'walks')
  child.type_keys('<esc>')
  -- go back to default
  for _ = 1, #opts.defaultOptions.enabledReplacementInterpreters - 1 do
    child.type_keys(keymaps.swapReplacementInterpreter.n)
  end
  helpers.childWaitForScreenshotText(child, '1 matches in 1 files')
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys('<esc>' .. keymaps.historyOpen.n)
  helpers.childWaitForScreenshotText(child, 'History')
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>12G', '<enter>')
  helpers.childWaitForScreenshotText(child, '2 matches in 1 files')
  helpers.childWaitForScreenshotText(child, '[lua]')
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.historyOpen.n)
  helpers.childWaitForScreenshotText(child, 'History')

  child.type_keys('<esc>3G', '<enter>')
  helpers.childWaitForScreenshotText(child, '1 matches in 1 files')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

return T
