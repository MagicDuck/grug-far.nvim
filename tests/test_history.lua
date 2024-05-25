local MiniTest = require('mini.test')
local helpers = require('grug-far/test/helpers')

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

T['can save and reload from history'] = function()
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
    prefills = { search = 'grug', flags = '-i' },
  })
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<C-p>')

  child.type_keys(50, '<esc>cc', 'walks')
  vim.loop.sleep(50)
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<C-p>')

  child.type_keys(50, '<esc>cc', 'talks')
  vim.loop.sleep(50)
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<C-p>')

  vim.loop.sleep(50)
  child.type_keys('<C-h>')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

return T
