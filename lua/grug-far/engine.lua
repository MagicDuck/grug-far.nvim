local M = {}

---@class grug.far.ParsedResultsStats
---@field files integer
---@field matches integer

---@class grug.far.ResultHighlightSign
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

  [M.ResultHighlightType.LineNumber] = 'GrugFarResultsLineNr',
  [M.ResultHighlightType.ColumnNumber] = 'GrugFarResultsColumnNr',
  [M.ResultHighlightType.NumbersSeparator] = 'GrugFarResultsNumbersSeparator',
}

---@type { [string]: grug.far.ResultHighlightSign }
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

---@class grug.far.SourceLocation
---@field filename string
---@field lnum? integer
---@field col? integer
---@field text? string
---@field is_counted? boolean

---@class grug.far.ResultHighlight
---@field hl_group string
---@field start_line integer
---@field start_col integer
---@field end_line integer
---@field end_col integer

---@class grug.far.ResultMark
---@field type ResultMarkType
---@field start_line integer
---@field start_col integer
---@field end_line integer
---@field end_col integer
---@field location? grug.far.SourceLocation
---@field sign? grug.far.ResultHighlightSign
---@field virt_text? string[][]
---@field virt_text_pos? string
---@field is_context? boolean

---@class grug.far.ParsedResultsData
---@field lines string[]
---@field marks grug.far.ResultMark[]
---@field highlights grug.far.ResultHighlight[]
---@field stats grug.far.ParsedResultsStats

---@class grug.far.EngineSearchParams
---@field inputs grug.far.Inputs
---@field options grug.far.Options
---@field replacementInterpreter? grug.far.ReplacementInterpreter
---@field on_fetch_chunk fun(data: grug.far.ParsedResultsData)
---@field on_finish fun(status: grug.far.Status, errorMessage: string?, customActionMessage: string?)

---@class grug.far.EngineReplaceParams
---@field inputs grug.far.Inputs
---@field options grug.far.Options
---@field replacementInterpreter? grug.far.ReplacementInterpreter
---@field report_progress fun(update: { type: "update_total" | "update_count", count: integer } | {type: "message", message: string})
---@field on_finish fun(status: grug.far.Status, errorMessage: string?, customActionMessage: string?)

---@class grug.far.ChangedLine
---@field lnum integer
---@field newLine string

---@class grug.far.ChangedFile
---@field filename string
---@field changedLines grug.far.ChangedLine[]

---@class grug.far.EngineSyncParams
---@field inputs grug.far.Inputs
---@field options grug.far.Options
---@field changedFiles grug.far.ChangedFile[]
---@field report_progress fun(update: { type: "update_total" | "update_count", count: integer })
---@field on_finish fun(status: grug.far.Status, errorMessage: string?, customActionMessage: string?)

---@class grug.far.EngineInput
---@field name string
---@field label string
---@field iconName string
---@field highlightLang? string
---@field trim boolean
---@field replacementInterpreterEnabled? boolean
---@field getDefaultValue? fun(context: grug.far.Context): string

---@class grug.far.Engine
---@field type grug.far.EngineType
---@field inputs grug.far.EngineInput[]
---@field isSearchWithReplacement fun(inputs: grug.far.Inputs, options: grug.far.Options): boolean is this a search with replacement
---@field showsReplaceDiff fun(options: grug.far.Options): boolean whether we show a diff when replacing
---@field search fun(params: grug.far.EngineSearchParams): (abort: fun()?, effectiveArgs: string[]?) performs search
---@field replace fun(params: grug.far.EngineReplaceParams): (abort: fun()?) performs replace
---@field isSyncSupported fun(): boolean whether sync operation is supported
---@field sync fun(params: grug.far.EngineSyncParams):
--- (abort: fun()?) syncs given changes to their originating files
---@field getInputPrefillsForVisualSelection fun(
---  visual_selection_info: grug.far.VisualSelectionInfo,
---  initialPrefills: grug.far.Prefills,
---  visualSelectionUsage: VisualSelectionUsageType): grug.far.Prefills gets prefills updated with visual selection (for example adds --fixed-strings for rg, etc)
---@field getSearchDescription fun(inputs: grug.far.Inputs): string a string describing the current search to be used as buffer title for example
---@field isEmptySearch fun(inputs: grug.far.Inputs, options: grug.far.Options): boolean whether search query is empty
---@field bufrangeInputName? grug.far.InputName name of input which can contain bufrange (for GrugFarWithin)

--- returns engine given type
---@param type grug.far.EngineType
---@return grug.far.Engine
function M.getEngine(type)
  if type == 'astgrep' then
    return require('grug-far.engine.astgrep')
  elseif type == 'astgrep-rules' then
    return require('grug-far.engine.astgrep-rules')
  end
  return require('grug-far.engine.ripgrep')
end

return M
