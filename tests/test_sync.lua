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

T['can sync all'] = function()
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

  child.type_keys('<esc>' .. keymaps.syncLocations.n)
  helpers.childWaitForUIVirtualText(child, 'sync completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys(50, '<esc>cc', 'curly')
  vim.loop.sleep(50)
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can sync all with changes ignoring deleted lines'] = function()
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
      and grug flies
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'curly' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys(10, '<esc>10G', 'dd')
  child.type_keys(10, 'A', ' a deep depth indeed!')
  child.type_keys(10, '<esc>13G', 'dd')
  child.type_keys(10, '$bi', 'believes he ')

  child.type_keys('<esc>' .. keymaps.syncLocations.n)

  helpers.childWaitForUIVirtualText(child, 'sync completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys(10, '<esc>3G', 'i', 'curly')
  vim.loop.sleep(50)
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['is prevented when multiline search'] = function()
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
    prefills = { search = 'grug', flags = '--multiline' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.syncLocations.n)

  helpers.childWaitForUIVirtualText(child, 'sync disabled')
  helpers.childExpectScreenshot(child)
end

T['can sync individual line'] = function()
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

  child.type_keys(10, '<esc>11G', 'A', ' a deep depth indeed!')

  child.type_keys('<esc>' .. keymaps.syncLine.n)

  helpers.childWaitForUIVirtualText(child, 'sync completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.refresh.n)
  vim.loop.sleep(50)
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

return T
