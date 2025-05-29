local help = require('grug-far.render.help')
local renderInput = require('grug-far.render.input')
local renderResults = require('grug-far.render.results')
local utils = require('grug-far.utils')

---@param buf integer
---@param context grug.far.Context
local function render(buf, context)
  local placeholders = context.options.engines[context.engine.type].placeholders
  local inputsHighlight = context.options.inputsHighlight

  local top_virt_lines = context.options.helpLine.enabled
      and help.getHelpVirtLines(context, context.actions)
    or {}

  if context.options.showInputsTopPadding then
    table.insert(top_virt_lines, { { '' } })
  end

  local lineNr = 0
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
      top_virt_lines = i == 1 and top_virt_lines or nil,
    }, context)

    lineNr = lineNr + 1
  end
  utils.fixShowTopVirtLines(context, buf)

  renderResults({
    buf = buf,
    minLineNr = lineNr,
    prevLabelExtmarkName = lastInput.name,
  }, context)
end

return render
