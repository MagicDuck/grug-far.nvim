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

T['engine swaps when reloading from history'] = function()
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
    engine = 'astgrep-rules',
    enabledEngines = { 'ripgrep', 'astgrep-rules' },
    prefills = { rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug.$A
    ]] },
  })
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys('<esc>' .. keymaps.swapEngine.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: swapped to engine')
  child.type_keys('<esc>cc', 'grug')
  helpers.childWaitForScreenshotText(child, '2 matches in 1 files')
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys('<esc>' .. keymaps.historyOpen.n)
  helpers.childWaitForScreenshotText(child, 'History')
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>11G', '<enter>')
  helpers.childWaitForScreenshotText(child, '1 matches in 1 files')
  helpers.childWaitForScreenshotText(child, 'astgrep')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.historyOpen.n)
  helpers.childWaitForScreenshotText(child, 'History')

  child.type_keys('<esc>3G', '<enter>')
  helpers.childWaitForScreenshotText(child, '2 matches in 1 files')
  helpers.childWaitForScreenshotText(child, 'ripgrep')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

return T
