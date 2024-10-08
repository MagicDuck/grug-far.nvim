local renderHelp = require('grug-far.render.help')
local renderInput = require('grug-far.render.input')
local renderResults = require('grug-far.render.results')
local utils = require('grug-far.utils')
local inputs = require('grug-far.inputs')
local InputNames = inputs.InputNames

local TOP_EMPTY_LINES = 1

---@param buf integer
---@param context GrugFarContext
local function render(buf, context)
  local state = context.state
  local placeholders = context.options.engines[context.engine.type].placeholders
  local inputsHighlight = context.options.inputsHighlight

  local lineNr = 0
  utils.ensureBufTopEmptyLines(buf, TOP_EMPTY_LINES)
  if context.options.helpLine.enabled then
    renderHelp({
      buf = buf,
      extmarkName = 'farHelp',
      actions = context.actions,
    }, context)
  end

  lineNr = lineNr + TOP_EMPTY_LINES
  state.inputs.search = renderInput({
    buf = buf,
    lineNr = lineNr,
    extmarkName = InputNames.search,
    nextExtmarkName = InputNames.replacement,
    icon = 'searchInput',
    label = 'Search:',
    placeholder = placeholders.enabled and placeholders.search,
    highlightLang = inputsHighlight and 'regex' or nil,
  }, context)

  lineNr = lineNr + 1
  local interpreterType = context.replacementInterpreter and context.replacementInterpreter.type
    or nil
  state.inputs.replacement = renderInput({
    buf = buf,
    lineNr = lineNr,
    prevExtmarkName = InputNames.search,
    extmarkName = InputNames.replacement,
    nextExtmarkName = InputNames.filesFilter,
    icon = 'replaceInput',
    label = interpreterType and 'Replace [' .. interpreterType .. ']:' or 'Replace:',
    placeholder = placeholders.enabled
      and (
        interpreterType and placeholders['replacement_' .. interpreterType]
        or placeholders.replacement
      ),
    highlightLang = inputsHighlight
        and (context.replacementInterpreter and context.replacementInterpreter.language or nil)
      or nil,
  }, context)

  lineNr = lineNr + 1
  state.inputs.filesFilter = vim.trim(renderInput({
    buf = buf,
    lineNr = lineNr,
    prevExtmarkName = InputNames.replacement,
    extmarkName = InputNames.filesFilter,
    nextExtmarkName = InputNames.flags,
    icon = 'filesFilterInput',
    label = 'Files Filter:',
    placeholder = placeholders.enabled and placeholders.filesFilter,
    highlightLang = inputsHighlight and 'gitignore' or nil,
  }, context))

  lineNr = lineNr + 1
  state.inputs.flags = vim.trim(renderInput({
    buf = buf,
    lineNr = lineNr,
    prevExtmarkName = InputNames.filesFilter,
    extmarkName = InputNames.flags,
    nextExtmarkName = InputNames.paths,
    icon = 'flagsInput',
    label = 'Flags:',
    placeholder = placeholders.enabled and placeholders.flags,
    highlightLang = inputsHighlight and 'bash' or nil,
  }, context))

  lineNr = lineNr + 1
  state.inputs.paths = vim.trim(renderInput({
    buf = buf,
    lineNr = lineNr,
    prevExtmarkName = InputNames.flags,
    extmarkName = InputNames.paths,
    nextExtmarkName = 'results_header',
    icon = 'pathsInput',
    label = 'Paths:',
    placeholder = placeholders.enabled and placeholders.paths,
    highlightLang = inputsHighlight and 'bash' or nil,
  }, context))

  lineNr = lineNr + 1
  renderResults({
    buf = buf,
    minLineNr = lineNr,
    prevLabelExtmarkName = 'paths',
  }, context)
end

return render
