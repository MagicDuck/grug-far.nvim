local search = require('grug-far.actions.search')
local engine = require('grug-far.engine')
local inputs = require('grug-far.inputs')

--- swaps engine with the next one
---@param params { buf: integer, context: GrugFarContext }
local function swapEngine(params)
  local context = params.context
  local buf = params.buf

  local engineTypes = context.options.enginesOrder
  local currentIndex = vim.fn.index(engineTypes, context.engine.type)
  local nextIndex = (currentIndex + 1) % #engineTypes
  local nextEngineType = engineTypes[nextIndex + 1]
  context.engine = engine.getEngine(nextEngineType)

  -- get the values and stuff them into savedValues
  for name, value in pairs(context.state.inputs) do
    context.state.previousInputValues[name] = value
  end
  -- clear the values and input label extmarks from the buffer
  local emptyValues = {}
  for _, input in ipairs(context.engine.inputs) do
    emptyValues[input.name] = ''
  end
  inputs.fill(context, buf, emptyValues, true)
  vim.api.nvim_buf_clear_namespace(buf, context.namespace, 0, -1)

  -- fill in inputs
  local values = {}
  for _, input in ipairs(context.engine.inputs) do
    local value = context.state.previousInputValues[input.name]
    if value == nil and input.getDefaultValue then
      value = input.getDefaultValue(context)
    end
    values[input.name] = value
  end

  vim.schedule(function()
    inputs.fill(context, buf, values, true)
    context.state.inputs = values

    vim.notify('grug-far: swapped to engine: ' .. context.engine.type .. '!', vim.log.levels.INFO)

    local win = vim.fn.bufwinid(buf)
    pcall(vim.api.nvim_win_set_cursor, win, { context.options.startCursorRow, 0 })
    search({ buf = buf, context = context })
  end)
end

return swapEngine
