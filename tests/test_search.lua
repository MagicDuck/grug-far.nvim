local MiniTest = require('mini.test')
local helpers = require('grug-far/test/helpers')
local screenshot = require('grug-far/test/screenshot')
local expect = MiniTest.expect

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

T['can search for some string'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'bob' },
  })

  helpers.childWaitForStatus(child, 'STATUS_SUCCESS')

  expect.reference_screenshot(screenshot.fromChildBufLines(child))
  expect.reference_screenshot(child.get_screenshot())
end

return T
