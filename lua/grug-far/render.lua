local renderHelp = require('grug-far.render.help')
local renderInput = require('grug-far.render.input')
local renderResults = require('grug-far.render.results')
local utils = require('grug-far.utils')

---@param buf integer
---@param context grug.far.Context
local function render(buf, context)
  local placeholders = context.options.engines[context.engine.type].placeholders
  local inputsHighlight = context.options.inputsHighlight

  if context.options.helpLine.enabled then
    renderHelp({
      buf = buf,
      extmarkName = 'farHelp',
      actions = context.actions,
    }, context)
  end

  -- add a blank line for aesthetics
  context.extmarkIds.top_blank_line = vim.api.nvim_buf_set_extmark(buf, context.namespace, 0, 0, {
    id = context.extmarkIds.top_blank_line,
    end_row = 0,
    end_col = 0,
    virt_lines = { { { '' } } },
    virt_lines_leftcol = true,
    virt_lines_above = true,
    right_gravity = false,
  })

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
