local MiniTest = require('mini.test')
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

T['can launch with :GrugFar astgrep'] = function()
  child.type_keys('<esc>:GrugFar astgrep<cr>')
  helpers.childWaitForScreenshotText(child, 'Search:')
  helpers.childWaitForScreenshotText(child, 'astgrep')
end

return T
