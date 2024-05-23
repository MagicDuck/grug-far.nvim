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

  helpers.childWaitForStatus(child, 'STATUS_SUCCESS')

  expect.reference_screenshot(child.get_screenshot())
  expect.reference_screenshot(screenshot.fromChildBufLines(child))
end

T['can search for some string with many matches'] = function()
  local files = {}
  for i = 1, 100 do
    table.insert(files, {
      filename = 'file_' .. i,
      content = [[
        grug walks many steps
        grug talks and grug drinks
        then grug thinks
      ]],
    })
  end
  helpers.writeTestFiles(files)

  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug' },
  })

  helpers.childWaitForStatus(child, 'STATUS_SUCCESS')

  expect.reference_screenshot(child.get_screenshot())
  expect.reference_screenshot(screenshot.fromChildBufLines(child))
end

return T
