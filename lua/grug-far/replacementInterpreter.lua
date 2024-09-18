local M = {}

---@class GrugFarReplacementInterpreter
---@field type GrugFarReplacementInterpreterType
---@field get_eval_fn fun(script: string): (fn: (fun(...): string)?, error: string?)

--- returns engine given type
---@param type GrugFarReplacementInterpreterType
---@return GrugFarReplacementInterpreter?
function M.getReplacementInterpreter(type)
  if type == 'lua' then
    return require('grug-far/replacementInterpreter/lua')
  end

  return nil
end

--- sets replacement interpreter
---@param context GrugFarContext
---@param type GrugFarReplacementInterpreterType
function M.setReplacementInterpreter(context, type)
  local currentType = context.replacementInterpreter and context.replacementInterpreter.type
    or 'default'
  if currentType == type then
    return
  end

  local interpreter = M.getReplacementInterpreter(type)
  context.replacementInterpreter = interpreter
  context.state.normalModeSearch = interpreter and true or false
end

return M
