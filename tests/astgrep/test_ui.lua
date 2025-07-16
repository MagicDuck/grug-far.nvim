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

T['can launch with :GrugFar astgrep'] = function()
  child.type_keys('<esc>:GrugFar astgrep<cr>')
  helpers.childWaitForScreenshotText(child, 'Search:')
  helpers.childWaitForScreenshotText(child, 'astgrep')
end

T['respects default input value when switching engine to astgrep'] = function()
  helpers.writeTestFiles({})
  helpers.childRunGrugFar(child, {
    enabledEngines = { 'ripgrep', 'astgrep' },
    prefills = {
      search = 'grug',
    },
    engines = {
      ripgrep = {
        defaults = {
          flags = '--smart-case --multiline',
        },
      },
      astgrep = {
        defaults = {
          flags = '--strictness relaxed',
        },
      },
    },
  })
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)

  -- to astgrep
  child.type_keys('<esc>' .. keymaps.swapEngine.n)
  helpers.childWaitForScreenshotText(child, 'astgrep')
  helpers.childExpectScreenshot(child)

  -- back to ripgrep
  child.type_keys('<esc>' .. keymaps.swapEngine.n)
  helpers.childWaitForScreenshotText(child, 'ripgrep')
  helpers.childExpectScreenshot(child)
end

return T
