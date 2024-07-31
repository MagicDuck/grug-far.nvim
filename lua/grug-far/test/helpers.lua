local MiniTest = require('mini.test')
local expect = MiniTest.expect
local screenshot = require('grug-far/test/screenshot')
local opts = require('grug-far/opts')

local M = {}

--- get list of virtual text chunks associated with given namespace in given buffer
---@param buf integer
---@param namespaceName string
---@return string[]
function M.getBufExtmarksVirtText(buf, namespaceName)
  local namespace = vim.api.nvim_create_namespace(namespaceName)
  local marks = vim.api.nvim_buf_get_extmarks(
    buf,
    namespace,
    { 0, 0 },
    { -1, -1 },
    { details = true }
  )

  local textChunks = {}

  for i = 1, #marks do
    local _, _, _, details = unpack(marks[i])
    local virt_lines = details.virt_lines
    if virt_lines then
      for j = 1, #virt_lines do
        local line = virt_lines[j]
        for k = 1, #line do
          local chunk = line[k]
          local text = unpack(chunk)
          table.insert(textChunks, text)
        end
      end
    end

    local virt_text = details.virt_text
    if virt_text then
      for l = 1, #virt_text do
        local chunk = virt_text[l]
        local text = unpack(chunk)
        table.insert(textChunks, text)
      end
    end
  end

  return textChunks
end

--- checks if virtual text associated with given namespace contains given string
---@param namespaceName string
---@param str string
---@return boolean
function M.bufVirtualTextContains(namespaceName, str)
  local textChunks = M.getBufExtmarksVirtText(0, namespaceName)
  for i = 1, #textChunks do
    local text = textChunks[i]
    if text:find(str, 1, true) then
      return true
    end
  end

  return false
end

---@alias NeovimChild any

--- checks if child neovim contains the given string
--- in the grug-far buffer UI namespace
---@param child NeovimChild
---@param str string
---@return boolean
function M.childBufUIVirtualTextContains(child, str)
  return child.lua_get('Helpers.bufVirtualTextContains(...)', { 'grug-far-namespace', str })
end

--- waits until condition fn evals to true, checking every interval ms
--- times out at timeout ms
---@param child NeovimChild
---@param condition fun(): boolean
---@param timeout? integer, defaults to 2000
---@param interval? integer, defaults to 100
function M.childWaitForCondition(child, condition, timeout, interval)
  local max = timeout or 2000
  local inc = interval or 100
  for _ = 0, max, inc do
    if condition() then
      return
    else
      vim.uv.sleep(inc)
    end
  end

  error(
    'Timed out waiting for condition after ' .. max .. 'ms!\n\n' .. tostring(child.get_screenshot())
  )
end

--- gets setup opts
---@return GrugFarOptionsOverride
function M.getSetupOptions()
  local rgPath = vim.env.RG_PATH or 'rg'

  return {
    rgPath = rgPath,
    -- sort by path so that we get things in the same order
    extraRgArgs = '--sort=path',
    icons = {
      resultsStatusReady = 'STATUS_READY',
      resultsStatusError = 'STATUS_ERROR',
      resultsStatusSuccess = 'STATUS_SUCCESS',
    },
    spinnerStates = { 'STATUS_PROGRESS' },
    reportDuration = false,
    -- note: child.type_keys does not like <localleader> so replacing with ','
    keymaps = {
      replace = { n = ',r' },
      qflist = { n = ',q' },
      syncLocations = { n = ',s' },
      syncLine = { n = ',l' },
      close = { n = ',c' },
      abort = { n = ',b' },
      historyOpen = { n = ',t' },
      historyAdd = { n = ',a' },
      refresh = { n = ',f' },
      openLocation = { n = ',o' },
      gotoLocation = { n = '<enter>' },
      pickHistoryEntry = { n = '<enter>' },
    },
    history = {
      historyDir = vim.uv.cwd() .. '/temp_history_dir',
    },
    windowCreationCommand = 'tab split',
    placeholders = { enabled = false },
  }
end

function M.getKeymaps()
  local options = opts.with_defaults(M.getSetupOptions(), opts.defaultOptions)
  return options.keymaps
end

--- init the child neovim process
---@param child NeovimChild
function M.initChildNeovim(child)
  -- Restart child process with custom 'init.lua' script
  child.restart({ '-u', 'scripts/minimal_init.lua' })

  child.lua(
    [[ 
    GrugFar = require('grug-far')
    GrugFar.setup(...)
    Helpers = require('grug-far/test/helpers')
  ]],
    {
      M.getSetupOptions(),
    }
  )
end

--- waits until child screenshot contains given virtual text
---@param child NeovimChild
---@param text string
function M.childWaitForScreenshotText(child, text)
  M.childWaitForCondition(child, function()
    local screenshotText = tostring(child.get_screenshot())
    return string.find(screenshotText, text, 1, true) ~= nil
  end)
end

--- waits until child screenshot does not contain given virtual text
---@param child NeovimChild
---@param text string
function M.childWaitForScreenshotNotContainingText(child, text)
  M.childWaitForCondition(child, function()
    local screenshotText = tostring(child.get_screenshot())
    return string.find(screenshotText, text, 1, true) == nil
  end)
end

--- waits until child buf contains given UI virtual text
---@param child NeovimChild
---@param text string
function M.childWaitForUIVirtualText(child, text)
  M.childWaitForCondition(child, function()
    return M.childBufUIVirtualTextContains(child, text)
  end)
end

---@param child NeovimChild
function M.cdTempTestDir(child)
  local cwd = vim.uv.cwd()
  child.lua('vim.api.nvim_set_current_dir("' .. cwd .. '/temp_test_dir")')
end

--- waits until child buf has given success or error status
---@param child NeovimChild
function M.childWaitForFinishedStatus(child)
  M.childWaitForCondition(child, function()
    return M.childBufUIVirtualTextContains(child, 'STATUS_SUCCESS')
      or M.childBufUIVirtualTextContains(child, 'STATUS_ERROR')
  end)
end

--- run grug_far(options) in child
---@param child NeovimChild
---@param options GrugFarOptionsOverride
---@return string instanceName
function M.childRunGrugFar(child, options)
  vim.fn.delete('./temp_history_dir', 'rf')
  vim.fn.mkdir('./temp_history_dir')

  M.cdTempTestDir(child)
  return child.lua_get('GrugFar.grug_far(...)', {
    options,
  })
end

--- writes files given based on given spec to temp test dir
--- clears out temp test dir beforehand
---@param files {[string]: string}
---@param dirs? string[]
function M.writeTestFiles(files, dirs)
  vim.fn.delete('./temp_test_dir', 'rf')
  vim.fn.mkdir('./temp_test_dir')
  if dirs then
    for _, dir in ipairs(dirs) do
      vim.fn.mkdir('./temp_test_dir/' .. dir)
    end
  end

  for i = 1, #files do
    local file = files[i]
    vim.fn.writefile(vim.split(file.content, '\n'), './temp_test_dir/' .. file.filename)
  end
end

--- expect child screenshot to match saved refeence screenshot
---@param child NeovimChild
function M.childExpectScreenshot(child)
  expect.reference_screenshot(
    child.get_screenshot(),
    nil,
    { force = not not vim.env['update_screenshots'] }
  )
end

--- expect child buf lines to match saved refeence screenshot
---@param child NeovimChild
function M.childExpectBufLines(child)
  expect.reference_screenshot(
    screenshot.fromChildBufLines(child),
    nil,
    { force = not not vim.env['update_screenshots'] }
  )
end

-- NOTE: for testing uncomment the following line, then open a grug-far buffer and execute
-- :luafile lua/grug-far/test/helpers.lua
-- P(M.bufVirtualTextContains('grug-far-namespace', 'Search'))

return M
