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

T['can replace with file filter'] = function()
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
    engine = 'astgrep-rules',
    prefills = {
      filesFilter = '**/*.ts',
      rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug
fix: curly]],
    },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)

  child.type_keys('<esc>' .. keymaps.swapEngine.n)
  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'curly.walks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace within one file'] = function()
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
    engine = 'astgrep-rules',
    prefills = {
      paths = './file2.ts',
      rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug
fix: curly
    ]],
    },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.swapEngine.n)
  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'curly.walks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace within one dir'] = function()
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
    engine = 'astgrep-rules',
    prefills = {
      paths = './',
      rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug
fix: curly
    ]],
    },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.swapEngine.n)
  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, 'curly.walks')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace within one dir with spaces'] = function()
  helpers.writeTestFiles({
    {
      filename = 'foo bar/file2.ts',
      content = [[ 
    if (grug || talks) {
      grug.walks(talks)
    }
    ]],
    },
  }, { 'foo bar' })

  helpers.childRunGrugFar(child, {
    engine = 'astgrep-rules',
    prefills = {
      paths = './foo\\ bar',
      rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug
fix: curly
    ]],
    },
  })
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.swapEngine.n)
  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, '(curly || talks)')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can replace within multiple dirs with spaces'] = function()
  helpers.writeTestFiles({
    {
      filename = 'hello world/file2.ts',
      content = [[ 
      if (grug || talks) {
        grug.walks(talks)
      }
    ]],
    },
  }, { 'foo bar', 'hello world' })

  helpers.childRunGrugFar(child, {
    engine = 'astgrep-rules',
    prefills = {
      paths = './foo\\ bar ./hello\\ world',
      rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug
fix: curly
    ]],
    },
  })
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>' .. keymaps.swapEngine.n)
  child.type_keys('<esc>cc', 'curly')
  helpers.childWaitForScreenshotText(child, '(curly || talks)')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['is prevented from replacing with blacklisted flags'] = function()
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
    engine = 'astgrep-rules',
    prefills = {
      flags = '--json',
      rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug
fix: curly
    ]],
    },
  })

  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)

  helpers.childWaitForScreenshotText(child, 'replace cannot work')
  helpers.childWaitForScreenshotText(child, 'error: the argument')
  helpers.childExpectScreenshot(child)
end

T['can replace within partial line range'] = function()
  helpers.writeTestFiles({
    {
      filename = 'file2.ts',
      content = [[ 
    if (grug || talks) {
      grug.walks(talks)
    }
    grug.jokes()
    ]],
    },
  })

  helpers.cdTempTestDir(child)
  child.cmd('e file2.ts')
  child.type_keys(10, 'ggVjj$')
  helpers.childRunGrugFar(child, {
    engine = 'astgrep-rules',
    prefills = {
      rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug
fix: curly
    ]],
    },
    visualSelectionUsage = 'operate-within-range',
  })

  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>' .. keymaps.replace.n)
  helpers.childWaitForUIVirtualText(child, 'replace completed!')
  helpers.childExpectScreenshot(child)
end

return T
