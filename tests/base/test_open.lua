local MiniTest = require('mini.test')
local helpers = require('grug-far/test/helpers')
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

T['can open a given location'] = function()
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
    windowCreationCommand = 'vsplit',
    prefills = { search = 'grug' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>11G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, 'Top file1.txt')
  helpers.childExpectScreenshot(child)
end

T['can open a location with count'] = function()
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
    windowCreationCommand = 'vsplit',
    prefills = { search = 'grug' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>2' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, 'Top file1.txt')
  helpers.childExpectScreenshot(child)
end

T['can open next location'] = function()
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
    windowCreationCommand = 'vsplit',
    prefills = { search = 'grug' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>')
  child.type_keys(keymaps.openNextLocation.n)
  helpers.childWaitForScreenshotText(child, '2,8')
  helpers.childExpectScreenshot(child)

  child.type_keys(keymaps.openNextLocation.n)
  helpers.childWaitForScreenshotText(child, '3,13')
  helpers.childExpectScreenshot(child)

  child.type_keys(keymaps.openNextLocation.n)
  helpers.childWaitForScreenshotText(child, '2,7')
  helpers.childExpectScreenshot(child)

  child.type_keys(keymaps.openNextLocation.n)
  helpers.childWaitForScreenshotText(child, '3,12')
  helpers.childExpectScreenshot(child)

  child.type_keys(keymaps.openNextLocation.n)
  vim.uv.sleep(100)
  helpers.childWaitForScreenshotText(child, '3,12')
  helpers.childExpectScreenshot(child)
end

return T
