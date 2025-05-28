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

T['can goto a specific input'] = function()
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
    prefills = { search = 'grug' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.lua('GrugFar.goto_input(...)', { 'replacement' })
  helpers.childWaitForScreenshotText(child, '2,1')
end

T['can goto first input'] = function()
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
    startCursorRow = 4,
    prefills = { search = 'grug' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.lua('GrugFar.goto_first_input()')
  helpers.childWaitForScreenshotText(child, '1,1')
end

T['can goto next input'] = function()
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
    startCursorRow = 4,
    prefills = { search = 'grug' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.lua('GrugFar.goto_next_input()')
  helpers.childWaitForScreenshotText(child, '5,1')
  child.lua('GrugFar.goto_next_input()')
  helpers.childWaitForScreenshotText(child, '1,1')
  child.lua('GrugFar.goto_next_input()')
  helpers.childWaitForScreenshotText(child, '2,1')

  child.type_keys('<esc>GG')
  child.lua('GrugFar.goto_next_input()')
  helpers.childWaitForScreenshotText(child, '1,1')

  -- check it works with keymap
  child.type_keys('<esc>' .. keymaps.nextInput.n)
  helpers.childWaitForScreenshotText(child, '2,0')
end

T['can goto prev input'] = function()
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
    startCursorRow = 2,
    prefills = { search = 'grug' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.lua('GrugFar.goto_prev_input()')
  helpers.childWaitForScreenshotText(child, '1,1')
  child.lua('GrugFar.goto_prev_input()')
  helpers.childWaitForScreenshotText(child, '5,1')
  child.lua('GrugFar.goto_prev_input()')
  helpers.childWaitForScreenshotText(child, '4,1')

  child.type_keys('<esc>GG')
  child.lua('GrugFar.goto_prev_input()')
  helpers.childWaitForScreenshotText(child, '5,0')

  -- check it works with keymap
  child.type_keys('<esc>' .. keymaps.prevInput.n)
  helpers.childWaitForScreenshotText(child, '4,0')
end

return T
