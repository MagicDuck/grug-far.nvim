local MiniTest = require('mini.test')
local helpers = require('grug-far/test/helpers')

-- TODO (sbadragan): split tests into base/ and astgrep/
-- add tests for it in a separate directory and run them in a separate github action
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

T['can disable keymaps and they disappear from UI'] = function()
  helpers.childRunGrugFar(child, {
    keymaps = {
      replace = false,
      syncLine = '',
    },
  })
  helpers.childExpectScreenshot(child)
end

return T
