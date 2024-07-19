local renderHelp = require('grug-far/render/help')
local renderInput = require('grug-far/render/input')
local renderResults = require('grug-far/render/results')
local utils = require('grug-far/utils')

local TOP_EMPTY_LINES = 2
local BEFORE_RESULTS_LINES = 2

---@param buf integer
---@param context GrugFarContext
local function render(buf, context)
  local inputs = context.state.inputs
  local placeholders = context.options.placeholders

  local lineNr = 0
  utils.ensureBufTopEmptyLines(buf, TOP_EMPTY_LINES)
  renderHelp({
    buf = buf,
    extmarkName = 'farHelp',
    actions = context.actions,
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
