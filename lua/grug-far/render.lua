local renderHelp = require('grug-far/render/help')
local renderInput = require('grug-far/render/input')
local renderResults = require('grug-far/render/results')

---@param buf integer
---@param count integer
local function ensureTopEmptyLines(buf, count)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, count, false)
  for _ = #lines + 1, count do
    table.insert(lines, nil)
  end

  local foundNonEmpty = false
  local emptyLines = {}
  for i = 1, #lines do
    local line = lines[i]
    foundNonEmpty = foundNonEmpty or not (line and #line == 0)
    if foundNonEmpty then
      table.insert(emptyLines, '')
    end
  end

  if #emptyLines > 0 then
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, emptyLines)
  end
end

local TOP_EMPTY_LINES = 2
local BEFORE_RESULTS_LINES = 2

---@param buf integer
---@param context GrugFarContext
local function render(buf, context)
  local inputs = context.state.inputs
  local placeholders = context.options.placeholders
  local keymaps = context.options.keymaps

  local lineNr = 0
  ensureTopEmptyLines(buf, TOP_EMPTY_LINES)
  renderHelp({
    buf = buf,
    actions = {
      { text = 'Replace', keymap = keymaps.replace },
      { text = 'Sync All', keymap = keymaps.syncLocations },
      { text = 'Sync Line', keymap = keymaps.syncLine },
      { text = 'History Open', keymap = keymaps.historyOpen },
      { text = 'History Add', keymap = keymaps.historyAdd },
      { text = 'Refresh', keymap = keymaps.refresh },
      { text = 'Goto', keymap = keymaps.gotoLocation },
      { text = 'Quickfix', keymap = keymaps.qflist },
      { text = 'Close', keymap = keymaps.close },
    },
  }, context)

  lineNr = lineNr + TOP_EMPTY_LINES
  inputs.search = renderInput({
    buf = buf,
    lineNr = lineNr,
    extmarkName = 'search',
    icon = 'searchInput',
    label = 'Search:',
    placeholder = placeholders.enabled and placeholders.search,
  }, context)

  lineNr = lineNr + 1
  inputs.replacement = renderInput({
    buf = buf,
    lineNr = lineNr,
    extmarkName = 'replace',
    icon = 'replaceInput',
    label = 'Replace:',
    placeholder = placeholders.enabled and placeholders.replacement,
  }, context)

  lineNr = lineNr + 1
  inputs.filesFilter = vim.trim(renderInput({
    buf = buf,
    lineNr = lineNr,
    extmarkName = 'files_glob',
    icon = 'filesFilterInput',
    label = 'Files Filter:',
    placeholder = placeholders.enabled and placeholders.filesFilter,
  }, context))

  lineNr = lineNr + 1
  inputs.flags = vim.trim(renderInput({
    buf = buf,
    lineNr = lineNr,
    extmarkName = 'flags',
    icon = 'flagsInput',
    label = 'Flags:',
    placeholder = placeholders.enabled and placeholders.flags,
  }, context))

  lineNr = lineNr + BEFORE_RESULTS_LINES
  renderResults({
    buf = buf,
    minLineNr = lineNr,
  }, context)
end

return render
