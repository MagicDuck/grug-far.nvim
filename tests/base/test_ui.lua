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

T['can launch with deprecated grug_far api'] = function()
  child.lua_get('GrugFar.grug_far(...)', {
    {},
  })
  helpers.childWaitForScreenshotText(child, 'ripgrep')
  helpers.childExpectScreenshot(child)
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

  -- TODO (sbadragan): add test for normalModeSearch
  helpers.childRunGrugFar(child, {
    searchOnInsertLeave = true,
  })

  helpers.childWaitForScreenshotText(child, 'Search:')
  child.type_keys('<esc>cc', 'walks')
  vim.uv.sleep(100)
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

return T
