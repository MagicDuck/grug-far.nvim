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

T['can toggle instance'] = function()
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
  helpers.cdTempTestDir(child)

  -- toggle on
  child.lua('GrugFar.toggle_instance(...)', {
    {
      instanceName = 'far',
      staticTitle = 'Find and Replace',
    },
  })
  child.type_keys(50, '<esc>cc', 'walks')
  helpers.childWaitForUIVirtualText(child, '1 matches in 1 files')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)

  -- toggle off
  child.lua('GrugFar.toggle_instance(...)', { { instanceName = 'far' } })
  helpers.sleep(child, 100)
  helpers.childExpectScreenshot(child)

  -- toggle on
  child.lua('GrugFar.toggle_instance(...)', { { instanceName = 'far' } })
  helpers.childWaitForUIVirtualText(child, '1 matches in 1 files')
  helpers.childExpectScreenshot(child)
end

T['can toggle instance after deletion of buffer'] = function()
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
  helpers.cdTempTestDir(child)

  -- toggle on
  child.lua('GrugFar.toggle_instance(...)', {
    {
      instanceName = 'far',
      staticTitle = 'Find and Replace',
    },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>cc', 'walks')
  helpers.childWaitForUIVirtualText(child, '1 matches in 1 files')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)

  -- delete
  child.type_keys('<esc>:bd<cr>')

  -- toggle on again
  child.lua('GrugFar.toggle_instance(...)', {
    {
      instanceName = 'far',
      staticTitle = 'Find and Replace',
    },
  })
  helpers.childWaitForScreenshotText(child, 'Find and Replace')
  helpers.childExpectScreenshot(child)
end

return T
