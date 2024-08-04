local M = {}

---@class ParsedResultsStats
---@field files integer
---@field matches integer

---@class ResultHighlightSign
---@field hl string
---@field icon string

---@class ResultHighlight
---@field hl string
---@field start_line integer
---@field start_col integer
---@field end_line integer
---@field end_col integer
---@field sign? ResultHighlightSign

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
---@field isSearchWithReplacement fun(inputs: GrugFarInputs, options: GrugFarOptions): boolean is this a search with replacement
---@field search fun(params: EngineSearchParams): (abort: fun()?, effectiveArgs: string[]?) performs search
---@field replace fun(params: EngineReplaceParams): (abort: fun()?) performs replace
---@field sync fun(params: EngineSyncParams): (abort: fun()?) syncs given changes to their originating files
---@field getInputPrefillsForVisualSelection fun(initialPrefills: GrugFarPrefills): GrugFarPrefills gets prefills updated with visual selection searchand any additional flags that are necessary (for example --fixed-strings for rg)

--- returns engine given type
---@param type GrugFarEngineType
---@return GrugFarEngine
function M.getEngine(type)
  local engine
  if not type or type == 'ripgrep' then
    engine = require('grug-far.engine.ripgrep')
  elseif type == 'astgrep' then
    engine = require('grug-far.engine.astgrep')
  end

  -- TODO (sbadragan): do / remove some of this
  -- Important Note:
  -- If we add another engine, we should:
  -- 1. add tests for it in a separate directory and run them in a separate github action
  -- 2. update history management so that history entries include an `Engine:` field, and we switch to that engine when history entry is picked
  -- 3. add an action to toggle engine?
  -- 4. display the engine somewhere in the UI?

  if not engine then
    error('Unsupported engine type: ' .. type)
  end

  return engine
end

return M
