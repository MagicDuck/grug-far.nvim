local search = require('grug-far/actions/search')
local replacementInterpreter = require('grug-far/replacementInterpreter')

--- swaps replacement interpreter with the next one
---@param params { buf: integer, context: GrugFarContext }
local function swapReplacementInterpreter(params)
  local context = params.context
  local buf = params.buf

  local interpreters = vim.fn.keys(context.options.replacementInterpreters)
  table.insert(interpreters, 'default')
  local currentIndex = vim.fn.index(
    interpreters,
    context.replacementInterpreter and context.replacementInterpreter.type or 'default'
  )
  local nextIndex = (currentIndex + 1) % #interpreters
  local nextInterpreterType = interpreters[nextIndex + 1]
  replacementInterpreter.setReplacementInterpreter(context, nextInterpreterType)
  vim.notify(
    'grug-far: swapped to replacement interpreter: '
      .. (context.replacementInterpreter and context.replacementInterpreter.type or 'default')
      .. '!',
    vim.log.levels.INFO
  )
  search({ buf = buf, context = context })
end

return swapReplacementInterpreter
