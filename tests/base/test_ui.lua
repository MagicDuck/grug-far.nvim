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

T['can disable keymaps and they disappear from UI'] = function()
  helpers.childRunGrugFar(child, {
    keymaps = {
      replace = false,
      syncLine = '',
    },
  })
  helpers.childExpectScreenshot(child)
end

T['can open with icons disabled'] = function()
  helpers.childRunGrugFar(child, {
    icons = { enabled = false },
  })
  helpers.childExpectScreenshot(child)
end

T['can launch with :GrugFar'] = function()
  child.type_keys('<esc>:GrugFar<cr>')
  helpers.childWaitForScreenshotText(child, 'Search:')
  helpers.childExpectScreenshot(child)
end

T['can launch with :GrugFar ripgrep'] = function()
  child.type_keys('<esc>:GrugFar<cr>')
  helpers.childWaitForScreenshotText(child, 'ripgrep')
end

return T
