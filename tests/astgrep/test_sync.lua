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

T['sync all is not supported'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file1.js',
      content = [[ 
    if (grug || another_thing) {
      console.log(grug)
    }
      ]],
    },
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
    prefills = { search = 'grug' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys(10, '<esc>7G', 'dd')
  child.type_keys(10, 'A', ' a deep depth indeed!')

  child.type_keys('<esc>' .. keymaps.syncLocations.n)

  helpers.childWaitForUIVirtualText(child, 'sync operation not supported')
end

T['sync line is not supported'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file1.js',
      content = [[ 
    if (grug || another_thing) {
      console.log(grug)
    }
      ]],
    },
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
    prefills = { search = 'grug' },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys(10, '<esc>7G', 'dd')
  child.type_keys(10, 'A', ' a deep depth indeed!')

  child.type_keys('<esc>' .. keymaps.syncLine.n)

  helpers.childWaitForUIVirtualText(child, 'sync operation not supported')
end

return T
