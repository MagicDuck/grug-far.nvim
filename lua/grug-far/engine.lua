local M = {}

---@class ParsedResultsStats
---@field files integer
---@field matches integer

---@class ResultHighlightSign
---@field hl string
---@field icon? string
---@field text? string

---@enum ResultMarkType
M.ResultMarkType = {
  DiffSeparator = 1,
  SourceLocation = 2,
  MatchCounter = 3,
}

---@enum ResultHighlightType
M.ResultHighlightType = {
  Match = 1,
  MatchAdded = 2,
  MatchRemoved = 3,
  FilePath = 4,
  NumberLabel = 5,
  LineNumber = 6,
  ColumnNumber = 7,
  NumbersSeparator = 8,
  LinePrefixEdge = 9,
}

---@type { [ResultHighlightType]: string }
M.ResultHighlightByType = {
  [M.ResultHighlightType.FilePath] = 'GrugFarResultsPath',
  [M.ResultHighlightType.Match] = 'GrugFarResultsMatch',
  [M.ResultHighlightType.MatchAdded] = 'GrugFarResultsMatchAdded',
  [M.ResultHighlightType.MatchRemoved] = 'GrugFarResultsMatchRemoved',
  [M.ResultHighlightType.NumberLabel] = 'GrugFarResultsNumberLabel',

  [M.ResultHighlightType.LineNumber] = 'GrugFarResultsLineNo',
  [M.ResultHighlightType.ColumnNumber] = 'GrugFarResultsLineColumn',
  [M.ResultHighlightType.NumbersSeparator] = 'GrugFarResultsNumbersSeparator',
  [M.ResultHighlightType.LinePrefixEdge] = 'GrugFarResultsLinePrefixEdge',
}

---@type { [string]: ResultHighlightSign }
M.ResultSigns = {
  Changed = { icon = 'resultsChangeIndicator', hl = 'GrugFarResultsChangeIndicator' },
  Removed = { icon = 'resultsRemovedIndicator', hl = 'GrugFarResultsRemoveIndicator' },
  Added = { icon = 'resultsAddedIndicator', hl = 'GrugFarResultsAddIndicator' },
  DiffSeparator = {
    icon = 'resultsDiffSeparatorIndicator',
    hl = 'GrugFarResultsDiffSeparatorIndicator',
  },
}

M.DiffSeparatorChars = ' '

---@class SourceLocation
---@field filename string
---@field lnum? integer
---@field col? integer
---@field text? string
---@field is_counted? boolean

---@class ResultHighlight
---@field hl_group string
---@field start_line integer
---@field start_col integer
---@field end_line integer
---@field end_col integer

---@class ResultMark
---@field type ResultMarkType
---@field start_line integer
---@field start_col integer
---@field end_line integer
---@field end_col integer
---@field location? SourceLocation
---@field sign? ResultHighlightSign
---@field virt_text? string[][]
---@field virt_text_pos? string

---@class ParsedResultsData
---@field lines string[]
---@field marks ResultMark[]
---@field highlights ResultHighlight[]
---@field stats ParsedResultsStats

---@class EngineSearchParams
---@field inputs GrugFarInputs
---@field options GrugFarOptions
---@field replacementInterpreter? GrugFarReplacementInterpreter
---@field on_fetch_chunk fun(data: ParsedResultsData)
---@field on_finish fun(status: GrugFarStatus, errorMessage: string?, customActionMessage: string?)

---@class EngineReplaceParams
---@field inputs GrugFarInputs
---@field options GrugFarOptions
---@field replacementInterpreter? GrugFarReplacementInterpreter
---@field report_progress fun(update: { type: "update_total" | "update_count", count: integer } | {type: "message", message: string})
---@field on_finish fun(status: GrugFarStatus, errorMessage: string?, customActionMessage: string?)

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
---@field on_finish fun(status: GrugFarStatus, errorMessage: string?, customActionMessage: string?)

---@class GrugFarEngineInput
---@field name string
---@field label string
---@field iconName string
---@field highlightLang? string
---@field trim boolean
---@field replacementInterpreterEnabled? boolean
---@field getDefaultValue? fun(context: GrugFarContext): string

---@class GrugFarEngine
---@field type GrugFarEngineType
---@field inputs GrugFarEngineInput[]
---@field isSearchWithReplacement fun(inputs: GrugFarInputs, options: GrugFarOptions): boolean is this a search with replacement
---@field showsReplaceDiff fun(options: GrugFarOptions): boolean whether we show a diff when replacing
---@field search fun(params: EngineSearchParams): (abort: fun()?, effectiveArgs: string[]?) performs search
---@field replace fun(params: EngineReplaceParams): (abort: fun()?) performs replace
---@field isSyncSupported fun(): boolean whether sync operation is supported
---@field sync fun(params: EngineSyncParams): (abort: fun()?) syncs given changes to their originating files
---@field getInputPrefillsForVisualSelection fun(visual_selection_info: VisualSelectionInfo, initialPrefills: GrugFarPrefills, visualSelectionUsage: VisualSelectionUsageType): GrugFarPrefills gets prefills updated with visual selection (for example adds --fixed-strings for rg, etc)
---@field getSearchDescription fun(inputs: GrugFarInputs): string a string describing the current search to be used as buffer title for example
---@field isEmptySearch fun(inputs: GrugFarInputs, options: GrugFarOptions): boolean whether search query is empty

--- returns engine given type
---@param type GrugFarEngineType
---@return GrugFarEngine
function M.getEngine(type)
  if type == 'astgrep' then
    return require('grug-far.engine.astgrep')
  elseif type == 'astgrep-rules' then
    return require('grug-far.engine.astgrep-rules')
  end
  return require('grug-far.engine.ripgrep')
end

return M
