local M = {}

---@class GrugFarReplacementInterpreter
---@field type GrugFarReplacementInterpreterType
---@field eval fun(script: string, params: {[string]: any}): (result: string?, error: string?)

--- returns engine given type
---@param type GrugFarReplacementInterpreterType
---@return GrugFarReplacementInterpreter?
function M.getReplacementInterpreter(type)
  if type == 'lua' then
    return require('grug-far/replacementInterpreter/lua')
  end

  return nil
end

return M
