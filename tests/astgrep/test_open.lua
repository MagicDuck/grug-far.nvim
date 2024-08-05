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
    {
      filename = 'file2.ts',
      content = [[ 
    if (grug || talks) {
      grug.walks(talks)
    }
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    engine = 'astgrep',
    windowCreationCommand = 'vsplit',
    prefills = { search = 'grug.$A' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>11G')
  child.type_keys('<esc>' .. keymaps.openLocation.n)
  helpers.childWaitForScreenshotText(child, 'All file2.ts')
  helpers.childExpectScreenshot(child)
end

return T
