local MiniTest = require('mini.test')
local expect = MiniTest.expect
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

T['can create instance, open, close and kill it'] = function()
  -- create it
  local instanceName = 'bob_instance'
  helpers.childRunGrugFar(child, { staticTitle = 'Find and Replace', instanceName = instanceName })
  helpers.childWaitForScreenshotText(child, 'Search:')
  helpers.childExpectScreenshot(child)

  -- check exists and is open
  expect.equality(child.lua_get('GrugFar.has_instance(...)', { instanceName }), true)
  expect.equality(child.lua_get('GrugFar.is_instance_open(...)', { instanceName }), true)

  -- close
  child.lua('GrugFar.close_instance(...)', { instanceName })
  helpers.childWaitForScreenshotNotContainingText(child, 'Search:')
  helpers.childExpectScreenshot(child)

  -- check exists and is not open
  expect.equality(child.lua_get('GrugFar.has_instance(...)', { instanceName }), true)
  expect.equality(child.lua_get('GrugFar.is_instance_open(...)', { instanceName }), false)

  -- open
  child.lua('GrugFar.open_instance(...)', { instanceName })
  helpers.childWaitForScreenshotText(child, 'Search:')
  helpers.childExpectScreenshot(child)

  -- check exists and is open
  expect.equality(child.lua_get('GrugFar.has_instance(...)', { instanceName }), true)
  expect.equality(child.lua_get('GrugFar.is_instance_open(...)', { instanceName }), true)

  -- open again (should do nothing)
  child.lua('GrugFar.open_instance(...)', { instanceName })
  helpers.childWaitForScreenshotText(child, 'Search:')
  helpers.childExpectScreenshot(child)

  -- check exists and is open
  expect.equality(child.lua_get('GrugFar.has_instance(...)', { instanceName }), true)
  expect.equality(child.lua_get('GrugFar.is_instance_open(...)', { instanceName }), true)

  -- kill
  child.lua('GrugFar.kill_instance(...)', { instanceName })
  helpers.childWaitForScreenshotNotContainingText(child, 'Search:')
  helpers.childExpectScreenshot(child)

  -- check not exists and is not open
  expect.equality(child.lua_get('GrugFar.has_instance(...)', { instanceName }), false)
  expect.equality(child.lua_get('GrugFar.is_instance_open(...)', { instanceName }), false)
end

T['can update instance prefills'] = function()
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

  -- create it
  local instanceName = 'bob_instance'
  helpers.childRunGrugFar(child, {
    staticTitle = 'Find and Replace',
    prefills = { search = 'grug' },
    instanceName = instanceName,
  })
  helpers.childWaitForScreenshotText(child, '5 matches in 2 files')

  -- prefill while keeping existing
  child.lua('GrugFar.update_instance_prefills(...)', { instanceName, { paths = 'file1.txt' } })
  helpers.childWaitForScreenshotText(child, '2 matches in 1 files')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)

  -- prefill while clearing old
  child.lua('GrugFar.update_instance_prefills(...)', { instanceName, { search = 'walks' }, true })
  helpers.childWaitForScreenshotText(child, '1 matches in 1 files')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

return T
