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

T['can apply next'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file1.txt',
      content = [[ 
      grug walks
      grug winks
    ]],
    },
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

  -- check nothing happens when triggering on a non-match location
  child.type_keys('<esc>' .. keymaps.applyNext.n)
  helpers.sleep(child, 50)
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.openNextLocation.n, 'k', keymaps.applyNext.n)
  helpers.sleep(child, 50)
  helpers.childExpectScreenshot(child)

  -- apply on each item in sequence
  child.type_keys('<esc>' .. keymaps.openNextLocation.n, keymaps.applyNext.n)
  helpers.childWaitForScreenshotNotContainingText(child, 'grug walks')
  helpers.childExpectScreenshot(child)
  child.type_keys('<esc>' .. keymaps.applyNext.n)
  helpers.childWaitForScreenshotNotContainingText(child, 'grug winks')
  helpers.childExpectScreenshot(child)
  child.type_keys('<esc>' .. keymaps.applyNext.n)
  helpers.childWaitForScreenshotNotContainingText(child, 'grug talks')
  helpers.childExpectScreenshot(child)
  child.type_keys('<esc>' .. keymaps.applyNext.n)
  helpers.childWaitForScreenshotNotContainingText(child, 'grug thinks')
  helpers.childExpectScreenshot(child)
end

T['can apply prev'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file1.txt',
      content = [[ 
      grug walks
      grug winks
    ]],
    },
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

  -- check nothing happens when triggering on a non-match location
  child.type_keys('<esc>' .. keymaps.applyPrev.n)
  helpers.sleep(child, 50)
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.openNextLocation.n, 'k', keymaps.applyPrev.n)
  helpers.sleep(child, 50)
  helpers.childExpectScreenshot(child)

  -- apply on each item in sequence
  child.type_keys('<esc>G', keymaps.applyPrev.n)
  helpers.childWaitForScreenshotNotContainingText(child, 'grug thinks')
  helpers.childExpectScreenshot(child)
  child.type_keys('<esc>' .. keymaps.applyPrev.n)
  helpers.childWaitForScreenshotNotContainingText(child, 'grug talks')
  helpers.childExpectScreenshot(child)
  child.type_keys('<esc>' .. keymaps.applyPrev.n)
  helpers.childWaitForScreenshotNotContainingText(child, 'grug winks')
  helpers.childExpectScreenshot(child)
  child.type_keys('<esc>' .. keymaps.applyPrev.n)
  helpers.childWaitForScreenshotNotContainingText(child, 'grug walks')
  helpers.childExpectScreenshot(child)
end

return T
