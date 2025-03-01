local search = require('grug-far.actions.search')
local engine = require('grug-far.engine')

--- swaps engine with the next one
---@param params { buf: integer, context: GrugFarContext }
local function swapEngine(params)
  local context = params.context
  local buf = params.buf

  local engineTypes = vim.fn.keys(context.options.engines)
  local currentIndex = vim.fn.index(engineTypes, context.engine.type)
  local nextIndex = (currentIndex + 1) % #engineTypes
  local nextEngineType = engineTypes[nextIndex + 1]
  context.engine = engine.getEngine(nextEngineType)
  vim.notify('grug-far: swapped to engine: ' .. context.engine.type .. '!', vim.log.levels.INFO)
  search({ buf = buf, context = context })

  -- TODO (sbadragan): need to somehow clear the extmark that was rendered for Search: input...
  -- and the associated value
  -- then fillInput with default for the ones that have a default.
end

return swapEngine
