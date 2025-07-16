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

T['can open with help line disabled'] = function()
  helpers.childRunGrugFar(child, {
    helpLine = { enabled = false },
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

T['can search manually on insert leave or normal mode change'] = function()
  helpers.writeTestFiles({
    { filename = 'file1', content = [[ grug walks ]] },
    {
      filename = 'file2',
      content = [[ 
      grug talks and grug drinks
      then grug thinks
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    searchOnInsertLeave = true,
  })

  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>cc', 'walks')
  helpers.sleep(child, 100)
  helpers.childExpectScreenshot(child)

  child.type_keys('<esc>')
  helpers.childWaitForUIVirtualText(child, '1 matches in 1 files')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)

  child.type_keys('0x')
  helpers.childWaitForUIVirtualText(child, '2 matches in 2 files')
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['p in empty input will not include newline'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>yy', 'j', 'p')
  helpers.childExpectScreenshot(child)
end

T['p - multiline in empty input will not include newline'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug\nsomething' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>Vjy', '2j', 'p')
  helpers.childExpectScreenshot(child)
end

T['p on last line of input will work'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'something' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>yy', 'j', 'p')
  helpers.childExpectScreenshot(child)
end

T['p in middle of input will work'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'something' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>viwy', 'j$', 'p')
  helpers.childExpectScreenshot(child)
end

T['p on first line of multiline input will work'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'something\nother' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>yy', 'j', 'p')
  helpers.childExpectScreenshot(child)
end

T['Vp in empty input will not include newline'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>yy', 'j', 'Vp')
  helpers.childExpectScreenshot(child)
end

T['Vp on last line of input will work'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'something\nelse' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>yy', 'jj', 'Vp')
  helpers.childExpectScreenshot(child)
end

----------------------------
T['P (above) in empty input will not include newline'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>yy', 'j', 'P')
  helpers.childExpectScreenshot(child)
end

T['P (above) - multiline in empty input will not include newline'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug\nsomething' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>Vjy', '2j', 'P')
  helpers.childExpectScreenshot(child)
end

T['P (above) on last line of input will work'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'something' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>yy', 'j', 'P')
  helpers.childExpectScreenshot(child)
end

T['P (above) in middle of input will work'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'something' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>viwy', 'jl', 'P')
  helpers.childExpectScreenshot(child)
end

T['P (above) on first line of multiline input will work'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'something\nother' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>yy', 'j', 'P')
  helpers.childExpectScreenshot(child)
end

T['VP (above) in empty input will not include newline'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>yy', 'j', 'VP')
  helpers.childExpectScreenshot(child)
end

T['VP (above) on last line of input will work'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'something\nelse' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>yy', 'jj', 'VP')
  helpers.childExpectScreenshot(child)
end

T['o in empty input does not break into next input'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = '' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>o')
  helpers.childExpectScreenshot(child)
end

T['o on last line of input does not break into next input'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'bob\ngrug' },
  })
  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>jo')
  helpers.childExpectScreenshot(child)
end

T['can change border style for help window'] = function()
  helpers.childRunGrugFar(child, {
    helpWindow = {
      border = 'none',
    },
  })
  child.type_keys('<esc>g?')
  helpers.childExpectScreenshot(child)
end

T['can change border style for history window'] = function()
  helpers.writeTestFiles({
    { filename = 'file1.txt', content = [[ grug walks ]] },
    {
      filename = 'file2.doc',
      content = [[
      grug talks and grug drinks
      then grug thinks and talks
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', flags = '-i' },
    historyWindow = {
      border = 'solid',
    },
  })
  helpers.childWaitForFinishedStatus(child)
  child.type_keys('<esc>' .. keymaps.historyAdd.n)
  helpers.childWaitForScreenshotText(child, 'grug-far: added current search to history')

  child.type_keys('<esc>' .. keymaps.historyOpen.n)
  helpers.childWaitForScreenshotText(child, 'History')
  helpers.childExpectScreenshot(child)
end

T['can change border style for preview window'] = function()
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
    previewWindow = {
      border = 'double',
    },
  })
  helpers.childWaitForFinishedStatus(child)

  child.type_keys('<esc>8G')
  child.type_keys('<esc>' .. keymaps.previewLocation.n)
  helpers.childExpectScreenshot(child)
end

T['can conceal long lines'] = function()
  helpers.writeTestFiles({
    { filename = 'file1', content = [[ grug walks ]] },
    {
      filename = 'file2_this_is_indeed_a_file_with_a_very_long_name_my_friends_and_i_reconize_that_it_is_quite_long_indeed',
      content = [[ 
      grug talks and grug drinks
      then grug thinks
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    wrap = false,
    prefills = {
      search = 'grug',
    },
  })
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can fold at filename'] = function()
  helpers.writeTestFiles({
    { filename = 'file1.txt', content = [[ grug walks ]] },
    {
      filename = 'file2.lua',
      content = [[ 
      grug talks and grug drinks
      then grug thinks
    ]],
    },
  })

  helpers.childRunGrugFar(child, {
    prefills = {
      search = 'grug',
    },
    folding = {
      enabled = true,
      include_file_path = true,
    },
  })
  helpers.childWaitForFinishedStatus(child)
  helpers.childWaitForScreenshotText(child, '4 matches in 2 files')
  child.type_keys(10, '<esc>:11<cr>', 'zc')
  helpers.childExpectScreenshot(child)
end

T['can display correctly with showCompactInputs=true'] = function()
  helpers.childRunGrugFar(child, {
    showCompactInputs = true,
  })
  helpers.childWaitForScreenshotText(child, 'READY')
  helpers.childExpectScreenshot(child)
end

T['can display correctly with showInputsTopPadding=false'] = function()
  helpers.childRunGrugFar(child, {
    showInputsTopPadding = false,
  })
  helpers.childWaitForScreenshotText(child, 'READY')
  helpers.childExpectScreenshot(child)
end

T['can display correctly with showInputsBottomPadding=false'] = function()
  helpers.childRunGrugFar(child, {
    showInputsBottomPadding = false,
  })
  helpers.childWaitForScreenshotText(child, 'READY')
  helpers.childExpectScreenshot(child)
end

T['can display correctly with showStatusInfo=false'] = function()
  helpers.writeTestFiles({
    { filename = 'file1', content = [[ grug walks ]] },
  })
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug' },
    showStatusInfo = false,
  })
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

T['can display correctly with showEngineInfo=false'] = function()
  helpers.childRunGrugFar(child, {
    showEngineInfo = false,
  })
  helpers.childWaitForScreenshotText(child, 'READY')
  helpers.childExpectScreenshot(child)
end

T['can display correctly with showStatusIcon=false'] = function()
  helpers.childRunGrugFar(child, {
    showStatusIcon = false,
  })
  helpers.childWaitForScreenshotText(child, 'Search')
  helpers.childExpectScreenshot(child)
end

T['can backspace newlines with backspaceEol enabled'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug\nwalks' },
    backspaceEol = true,
  })
  child.type_keys('<esc>', 'j', 'I', '<bs>')
  helpers.childExpectScreenshot(child)
end

T['deleting with bs from start of input is ignored even with backspaceEol'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'walks' },
    backspaceEol = true,
  })

  child.type_keys('<esc>', 'j', 'I', '<bs>')
  helpers.childExpectScreenshot(child)
end

T['deleting with C-u from start of input is ignored even with backspaceEol'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'walks' },
    backspaceEol = true,
  })

  child.type_keys('<esc>', 'j', 'I', '<C-u>')
  helpers.childExpectScreenshot(child)
end

T['deleting with C-w from start of input is ignored even with backspaceEol'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'walks' },
    backspaceEol = true,
  })

  child.type_keys('<esc>', 'j', 'I', '<C-w>')
  helpers.childExpectScreenshot(child)
end

T['deleting from end of input is ignored even with backspaceEol'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug', replacement = 'walks' },
    backspaceEol = true,
  })
  child.type_keys('<esc>', 'A', '<del>')
  helpers.childExpectScreenshot(child)
end

T['deleting from end of multiline input is ignored even with backspaceEol'] = function()
  helpers.childRunGrugFar(child, {
    prefills = { search = 'grug\nwalks', replacement = 'grug walks' },
    backspaceEol = true,
  })
  child.type_keys('<esc>', 'j', 'A', '<del>')
  helpers.childExpectScreenshot(child)
end

T['respects default input value on load'] = function()
  helpers.writeTestFiles({})
  helpers.childRunGrugFar(child, {
    prefills = {
      search = 'grug',
    },
    engines = {
      ripgrep = {
        defaults = {
          search = 'hello',
          flags = '--smart-case',
        },
      },
    },
  })
  helpers.childWaitForFinishedStatus(child)
  helpers.childExpectScreenshot(child)
end

return T
