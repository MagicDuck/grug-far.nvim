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

T['can search for some string'] = function()
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
    prefills = { rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug.$A
    ]] },
  })

  helpers.childWaitForFinishedStatus(child)

  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['can search for some string with placeholders on'] = function()
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
    prefills = { rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug
    ]] },
    engines = {
      ['astgrep-rules'] = {
        placeholders = { enabled = true },
      },
    },
  })

  helpers.childWaitForFinishedStatus(child)

  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['reports error from ast-grep'] = function()
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
    -- note: invalid regex
    prefills = {
      flags = '--strictness',
      rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug
    ]],
    },
  })

  helpers.childWaitForFinishedStatus(child)

  helpers.childExpectScreenshot(child)
end

T['can search with flags'] = function()
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
      flags = '--threads=1',
      rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug
    ]],
    },
  })

  helpers.childWaitForFinishedStatus(child)

  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['can search with flags resulting in plain text output'] = function()
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
      flags = '--help',
      rules = [[
      id: grug_test
      language: typescript
      rule:
        pattern: grug.$A
          ]],
    },
  })

  helpers.childWaitForFinishedStatus(child)
  helpers.childWaitForScreenshotText(child, 'Usage:')
end

T['can search with particular file in paths'] = function()
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
      ]],
    },
  })

  helpers.childWaitForFinishedStatus(child)

  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['can search with particular dir in paths'] = function()
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
      paths = '.',
      rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug
    ]],
    },
  })

  helpers.childWaitForFinishedStatus(child)

  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['can search with file filter'] = function()
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
    ]],
    },
  })

  helpers.childWaitForFinishedStatus(child)

  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['can search with replace string'] = function()
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
      replacement = 'curly',
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
  helpers.childExpectBufLines(child)
end

T['can search with no matches'] = function()
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
      rules = [[
id: grug_test
language: typescript
rule:
  pattern: george
    ]],
    },
  })

  helpers.childWaitForFinishedStatus(child)

  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['can search with files filter and no matches'] = function()
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
      filesFilter = '*.ts',
      rules = [[
id: grug_test
language: typescript
rule:
  pattern: george
    ]],
    },
  })

  helpers.childWaitForFinishedStatus(child)

  helpers.childExpectScreenshot(child)
  helpers.childExpectBufLines(child)
end

T['can search for some string with many matches'] = function()
  local files = {}
  for i = 1, 100 do
    table.insert(files, {
      filename = 'file_' .. i .. '.ts',
      content = [[
        if (grug || talks) {
          grug.walks(talks)
        }
      ]],
    })
  end
  helpers.writeTestFiles(files)

  helpers.childRunGrugFar(child, {
    engine = 'astgrep-rules',
    prefills = {
      rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug
]],
    },
  })

  helpers.childWaitForFinishedStatus(child)
  helpers.childWaitForScreenshotText(child, '200 matches in 100 files')
end

T['can search for visual selection inside one line'] = function()
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

  helpers.cdTempTestDir(child)
  child.cmd(':e file2.ts')
  child.type_keys(10, 'jj', 'veee', '<esc>:<C-u>lua GrugFar.with_visual_selection()<CR>')

  helpers.childWaitForFinishedStatus(child)

  helpers.childExpectScreenshot(child)
end

T['searches full line visual selection'] = function()
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

  helpers.cdTempTestDir(child)
  child.cmd(':e file2.ts')
  child.type_keys(10, 'j', '0v$', '<esc>:lua GrugFar.with_visual_selection()<CR>')

  helpers.childWaitForFinishedStatus(child)

  helpers.childExpectScreenshot(child)
end

T['is prevented from searching with blacklisted flags'] = function()
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
      flags = '--rule',
      rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug
      ]],
    },
  })

  helpers.childWaitForScreenshotText(child, 'search cannot work')
  helpers.childExpectScreenshot(child)
end

T['can search within partial line range'] = function()
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
    prefills = { rules = [[
id: grug_test
language: typescript
rule:
  pattern: grug.$A
    ]] },
    visualSelectionUsage = 'operate-within-range',
  })

  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

return T
