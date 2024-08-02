local M = {}

---@alias GrugFarEngineType "ripgrep"
-- note: in the future, we can add other types here, ex: "ripgrep" | "foobar"

---@class GrugFarEngine
---@field type GrugFarEngineType
---@field search fun(params: string): string

--- returns engine given type
---@param type GrugFarEngineType
---@return GrugFarEngine
function M.getEngine(type)
  if not type or type == 'ripgrep' then
    return require('grug-far.engine.ripgrep')
  end

  error('Unsupported engine type: ' .. type)
end

return M
