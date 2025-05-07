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

T['closes without error'] = function()
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

  child.type_keys('<esc>' .. keymaps.close.n)
  helpers.childWaitForScreenshotNotContainingText(child, 'Grug FAR')
  helpers.childExpectScreenshot(child)
end

return T
