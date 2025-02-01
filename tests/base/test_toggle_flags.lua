local MiniTest = require('mini.test')
local helpers = require('grug-far.test.helpers')

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

T['can toggle one flag'] = function()
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
    prefills = { search = 'gru?' },
  })
  helpers.childWaitForFinishedStatus(child)

  -- toggle flag on
  child.lua('GrugFar.toggle_flags(...)', {
    { '--fixed-strings' },
  })
  helpers.childWaitForScreenshotText(child, 'no matches')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)

  -- toggle flag off
  child.lua('GrugFar.toggle_flags(...)', {
    { '--fixed-strings' },
  })
  helpers.childWaitForScreenshotText(child, '5 matches')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

return T
