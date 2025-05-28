local renderHelp = require('grug-far.render.help')
local renderInput = require('grug-far.render.input')
local renderResults = require('grug-far.render.results')
local utils = require('grug-far.utils')

-- note: this was previously used to work around a nvim bug. Leaving it in for now
-- this bug: https://github.com/neovim/neovim/issues/16166
local TOP_EMPTY_LINES = 0

---@param buf integer
---@param context grug.far.Context
local function render(buf, context)
  local placeholders = context.options.engines[context.engine.type].placeholders
  local inputsHighlight = context.options.inputsHighlight

  local lineNr = 0
  if TOP_EMPTY_LINES > 0 then
    utils.ensureBufTopEmptyLines(buf, TOP_EMPTY_LINES)
  end
  if context.options.helpLine.enabled then
    renderHelp({
      buf = buf,
      extmarkName = 'farHelp',
      actions = context.actions,
    }, context)
  end

  lineNr = lineNr + TOP_EMPTY_LINES

  local lastInput
  for i, input in ipairs(context.engine.inputs) do
    lastInput = input
    local prevInput = context.engine.inputs[i - 1]
    local nextInput = context.engine.inputs[i + 1]

    local label = input.label
    local placeholder = placeholders[input.name]
    local highlightLang = input.highlightLang

    if input.replacementInterpreterEnabled then
      local interpreterType = context.replacementInterpreter and context.replacementInterpreter.type
        or nil
      if interpreterType then
        label = label .. ' [' .. interpreterType .. ']'
        placeholder = placeholders[input.name .. '_' .. interpreterType]
        highlightLang = context.replacementInterpreter.language
      end
    end

    renderInput({
      buf = buf,
      lineNr = lineNr,
      extmarkName = input.name,
      prevExtmarkName = prevInput and prevInput.name or nil,
      nextExtmarkName = nextInput and nextInput.name or 'results_header',
      icon = input.iconName,
      label = label .. ':',
      placeholder = placeholders.enabled and placeholder,
      highlightLang = inputsHighlight and highlightLang or nil,
    }, context)

    lineNr = lineNr + 1
  end
  utils.fixShowTopVirtLines(context)

  renderResults({
    buf = buf,
    minLineNr = lineNr,
    prevLabelExtmarkName = lastInput.name,
  }, context)
end

return render
