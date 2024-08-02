local M = {}

---@class ParsedResultsStats
---@field files integer
---@field matches integer

---@class ResultHighlight
---@field hl string
---@field start_line integer
---@field start_col integer
---@field end_line integer
---@field end_col integer

---@class ParsedResultsData
---@field lines string[]
---@field highlights ResultHighlight[] in source order
---@field stats ParsedResultsStats

---@class EngineSearchParams
---@field inputs GrugFarInputs
---@field options GrugFarOptions
---@field on_fetch_chunk fun(data: ParsedResultsData)
---@field on_finish fun(status: GrugFarStatus, errorMesage: string | nil)

---@class EngineReplaceParams
---@field inputs GrugFarInputs
---@field options GrugFarOptions
---@field report_progress fun(update: { type: "update_total" | "update_count", count: integer })
---@field on_finish fun(status: GrugFarStatus, errorMesage: string?, customActionMessage: string?)

---@class ChangedLine
---@field lnum integer
---@field newLine string

---@class ChangedFile
---@field filename string
---@field changedLines ChangedLine[]

---@class EngineSyncParams
---@field inputs GrugFarInputs
---@field options GrugFarOptions
---@field changedFiles ChangedFile[]
---@field report_progress fun(update: { type: "update_total" | "update_count", count: integer })
---@field on_finish fun(status: GrugFarStatus, errorMesage: string?, customActionMessage: string?)

---@class GrugFarEngine
---@field type GrugFarEngineType
---@field search fun(params: EngineSearchParams): (abort: fun()?, effectiveArgs: string[]?)
---@field replace fun(params: EngineReplaceParams): (abort: fun()?)
---@field sync fun(params: EngineSyncParams): (abort: fun()?)

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
