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

  child.type_keys('<C-enter>')
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  expect.reference_screenshot(child.get_screenshot())
  expect.reference_screenshot(screenshot.fromChildBufLines(child))

  child.type_keys('<esc>cc', 'curly')
  vim.loop.sleep(50)
  helpers.childWaitForFinishedStatus(child)
  expect.reference_screenshot(child.get_screenshot())
end

return T
