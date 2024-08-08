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
  local placeholders = context.options.engines[context.engine.type].placeholders

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
    nextExtmarkName = 'replace',
    icon = 'searchInput',
    label = 'Search:',
    placeholder = placeholders.enabled and placeholders.search,
  }, context)

  lineNr = lineNr + 1
  inputs.replacement = renderInput({
    buf = buf,
    lineNr = lineNr,
    prevExtmarkName = 'search',
    extmarkName = 'replace',
    nextExtmarkName = 'files_glob',
    icon = 'replaceInput',
    label = 'Replace:',
    placeholder = placeholders.enabled and placeholders.replacement,
  }, context)

  lineNr = lineNr + 1
  inputs.filesFilter = vim.trim(renderInput({
    buf = buf,
    lineNr = lineNr,
    prevExtmarkName = 'replace',
    extmarkName = 'files_glob',
    nextExtmarkName = 'flags',
    icon = 'filesFilterInput',
    label = 'Files Filter:',
    placeholder = placeholders.enabled and placeholders.filesFilter,
  }, context))

  lineNr = lineNr + 1
  inputs.flags = vim.trim(renderInput({
    buf = buf,
    lineNr = lineNr,
    prevExtmarkName = 'files_glob',
    extmarkName = 'flags',
    nextExtmarkName = 'paths',
    icon = 'flagsInput',
    label = 'Flags:',
    placeholder = placeholders.enabled and placeholders.flags,
  }, context))

  lineNr = lineNr + 1
  inputs.paths = vim.trim(renderInput({
    buf = buf,
    lineNr = lineNr,
    prevExtmarkName = 'flags',
    extmarkName = 'paths',
    nextExtmarkName = 'results_header',
    icon = 'pathsInput',
    label = 'Paths:',
    placeholder = placeholders.enabled and placeholders.paths,
  }, context))

  lineNr = lineNr + BEFORE_RESULTS_LINES
  renderResults({
    buf = buf,
    minLineNr = lineNr,
    numLinesAbove = BEFORE_RESULTS_LINES,
    prevLabelExtmarkName = 'paths',
  }, context)
end

return render
