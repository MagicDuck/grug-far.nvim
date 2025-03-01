local renderHelp = require('grug-far.render.help')
local renderInput = require('grug-far.render.input')
local renderResults = require('grug-far.render.results')
local utils = require('grug-far.utils')

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

  lineNr = lineNr + TOP_EMPTY_LINES - 1

  for i, input in ipairs(context.engine.inputs) do
    lineNr = lineNr + 1
    local nextInput = context.engine.inputs[i + 1]

    local label = input.label
    local placeholder = placeholders[input.name]
    local highlightLang = input.highlightLang

    -- special treatment for replacement interpreter
    if input.name == 'replacement' then
      local interpreterType = context.replacementInterpreter and context.replacementInterpreter.type
        or nil
      if interpreterType then
        label = label .. ' [' .. interpreterType .. ']'
        placeholder = placeholders[input.name .. '_' .. interpreterType]
        highlightLang = context.replacementInterpreter.language
      end
    end

    local value = renderInput({
      buf = buf,
      lineNr = lineNr,
      extmarkName = input.name,
      nextExtmarkName = nextInput and nextInput.name or 'results_header',
      icon = input.iconName,
      label = label .. ':',
      placeholder = placeholders.enabled and placeholder,
      highlightLang = inputsHighlight and highlightLang or nil,
    }, context)

    state.inputs[input.name] = input.trim and vim.trim(value) or value
  end

  lineNr = lineNr + 1
  renderResults({
    buf = buf,
    minLineNr = lineNr,
    prevLabelExtmarkName = 'paths',
  }, context)
end

return render
