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
    prefills = { search = 'grug' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>8G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, '3,13')
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
    prefills = { search = 'grug' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>2' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, '3,13')
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
  helpers.childWaitForScreenshotText(child, '3,12')
  helpers.childExpectScreenshot(child)
end

T['can open prev location'] = function()
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
    prefills = { search = 'grug' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>')
  child.type_keys(keymaps.openNextLocation.n)
  child.type_keys(keymaps.openNextLocation.n)
  child.type_keys(keymaps.openNextLocation.n)

  child.type_keys(keymaps.openPrevLocation.n)
  helpers.childWaitForScreenshotText(child, '3,13')
  helpers.childExpectScreenshot(child)

  child.type_keys(keymaps.openPrevLocation.n)
  helpers.childWaitForScreenshotText(child, '2,8')
  helpers.childExpectScreenshot(child)

  child.type_keys(keymaps.openPrevLocation.n)
  helpers.sleep(child, 100)
  helpers.childWaitForScreenshotText(child, '2,8')
  helpers.childExpectScreenshot(child)
end

T['can open a given location when only window in tabpage'] = function()
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
    prefills = { search = 'grug' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>8G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, '3,13')
  helpers.childExpectScreenshot(child)
end

T['can open a given location with left preferredLocation'] = function()
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
    prefills = { search = 'grug' },
    openTargetWindow = { preferredLocation = 'left' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>8G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, '3,13')
  helpers.childExpectScreenshot(child)

  -- check that the window gets reused
  child.type_keys('<esc>11G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, '2,7')
  helpers.childExpectScreenshot(child)
end

T['can open a given location with right preferredLocation'] = function()
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
    prefills = { search = 'grug' },
    openTargetWindow = { preferredLocation = 'right' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>8G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, '3,13')
  helpers.childExpectScreenshot(child)

  -- check that the window gets reused
  child.type_keys('<esc>11G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, '2,7')
  helpers.childExpectScreenshot(child)
end

T['can open a given location with above preferredLocation'] = function()
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
    prefills = { search = 'grug' },
    openTargetWindow = { preferredLocation = 'above' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>8G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, '3,13')
  helpers.childExpectScreenshot(child)

  -- check that the window gets reused
  child.type_keys('<esc>11G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, '2,7')
  helpers.childExpectScreenshot(child)
end

T['can open a given location with below preferredLocation'] = function()
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
    prefills = { search = 'grug' },
    openTargetWindow = { preferredLocation = 'below' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>8G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, '3,13')
  helpers.childExpectScreenshot(child)

  -- check that the window gets reused
  child.type_keys('<esc>11G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, '2,7')
  helpers.childExpectScreenshot(child)
end

T['respects exclude filetype when opening location'] = function()
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

  child.type_keys('<esc>:set filetype=lua<cr>')
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug' },
    openTargetWindow = { preferredLocation = 'right', exclude = { 'lua' } },
    windowCreationCommand = 'vsplit',
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>8G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, '3,13')
  helpers.childExpectScreenshot(child)

  -- check that the window gets reused
  child.type_keys('<esc>11G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, '2,7')
  helpers.childExpectScreenshot(child)
end

T['respects exclude function when opening location'] = function()
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

  child.type_keys('<esc>:set filetype=lua<cr>')
  vim.fn.delete('./temp_history_dir', 'rf')
  vim.fn.mkdir('./temp_history_dir')
  helpers.cdTempTestDir(child)
  child.lua([[
    GrugFar.open({
      prefills = { search = 'grug' },
      openTargetWindow = {
        preferredLocation = 'right',
        exclude = {
          function(w)
            local b = vim.api.nvim_win_get_buf(w)
            local filetype = vim.api.nvim_get_option_value('filetype', { buf = b })
            return filetype == 'lua'
          end,
        },
      },
      windowCreationCommand = 'vsplit',
    })
  ]])

  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>8G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, '3,13')
  helpers.childExpectScreenshot(child)

  -- check that the window gets reused
  child.type_keys('<esc>11G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, '2,7')
  helpers.childExpectScreenshot(child)
end

return T
