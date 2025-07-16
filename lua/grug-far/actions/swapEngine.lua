local engine = require('grug-far.engine')
local history = require('grug-far.history')
local inputs = require('grug-far.inputs')

--- swaps engine with the next one
---@param params { buf: integer, context: grug.far.Context }
local function swapEngine(params)
  local context = params.context
  local buf = params.buf

  local engineTypes = context.options.enabledEngines
  local currentIndex = vim.fn.index(engineTypes, context.engine.type)
  local nextIndex = (currentIndex + 1) % #engineTypes
  local nextEngineType = engineTypes[nextIndex + 1]
  local nextEngine = engine.getEngine(nextEngineType)
  local nextEngineOpts = context.options.engines[nextEngineType]

  for name, value in pairs(inputs.getValues(context, buf)) do
    context.state.previousInputValues[name] = value
  end

  local entry = {
    engine = nextEngineType,
  }
  for _, input in ipairs(nextEngine.inputs) do
    local value
    if nextEngineOpts.defaults[input.name] then
      value = nextEngineOpts.defaults[input.name]
    end
    if not value and input.getDefaultValue then
      value = input.getDefaultValue(context)
    end
    if value == nil then
      value = context.state.previousInputValues[input.name] or ''
    end
    entry[input.name] = value
  end

  history.fillInputsFromEntry(context, buf, entry, function()
    vim.notify('grug-far: swapped to engine: ' .. context.engine.type .. '!', vim.log.levels.INFO)
  end)
end

return swapEngine
