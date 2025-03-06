local MiniTest = require('mini.test')
local helpers = require('grug-far.test.helpers')
local keymaps = helpers.getKeymaps()
local opts = require('grug-far.opts')

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

T['engine swaps when reloading from history'] = function()
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
    enabledEngines = { 'ripgrep', 'astgrep' },
    prefills = { search = 'grug.$A' },
  })
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys('<esc>cc', 'grug')
  child.type_keys('<esc>' .. keymaps.swapEngine.n)
  helpers.childWaitForScreenshotText(child, '2 matches in 1 files')
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys('<esc>' .. keymaps.historyOpen.n)
  helpers.childWaitForScreenshotText(child, 'History')
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>11G', '<enter>')
  helpers.childWaitForScreenshotText(child, '1 matches in 1 files')
  helpers.childWaitForScreenshotText(child, 'astgrep')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.historyOpen.n)
  helpers.childWaitForScreenshotText(child, 'History')

  child.type_keys('<esc>3G', '<enter>')
  helpers.childWaitForScreenshotText(child, '2 matches in 1 files')
  helpers.childWaitForScreenshotText(child, 'ripgrep')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['replacement interpreter swaps when reloading from history'] = function()
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
    enabledEngines = { 'ripgrep', 'astgrep' },
    prefills = { search = 'grug.$A', replacement = 'return vars.A' },
    replacementInterpreter = 'lua',
  })
  helpers.childWaitForFinishedStatus(child)
  helpers.childWaitForScreenshotText(child, '[lua]')
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys('<esc>cc', '$A')
  child.type_keys('<esc>')
  -- go back to default
  for _ = 1, #opts.defaultOptions.enabledReplacementInterpreters - 1 do
    child.type_keys(keymaps.swapReplacementInterpreter.n)
  end
  helpers.childWaitForScreenshotText(child, '14 matches in 1 files')
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys('<esc>' .. keymaps.historyOpen.n)
  helpers.childWaitForScreenshotText(child, 'History')
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>11G', '<enter>')
  helpers.childWaitForScreenshotText(child, '1 matches in 1 files')
  helpers.childWaitForScreenshotText(child, '[lua]')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.historyOpen.n)
  helpers.childWaitForScreenshotText(child, 'History')

  child.type_keys('<esc>3G', '<enter>')
  helpers.childWaitForScreenshotText(child, '14 matches in 1 files')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

return T
