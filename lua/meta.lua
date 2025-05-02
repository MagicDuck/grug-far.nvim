---@meta
---@alias GrugFarStatus nil | "success" | "error" | "progress"

---@class ResultLocation: SourceLocation
---@field count? integer
---@field max_line_number_length? integer
---@field max_column_number_length? integer
---@field is_context? boolean

---@alias GrugFarInputName "search" | "rules" | "replacement" | "filesFilter" | "flags" | "paths"

---@class GrugFarInputs
---@field [GrugFarInputName] string?

---@class GrugFarState
---@field lastInputs? GrugFarInputs
---@field status? GrugFarStatus
---@field progressCount? integer
---@field stats? { matches: integer, files: integer }
---@field actionMessage? string
---@field resultLocationByExtmarkId { [integer]: ResultLocation }
---@field resultMatchLineCount integer
---@field lastCursorLocation { loc:  ResultLocation, row: integer, markId: integer }
---@field tasks GrugFarTask[]
---@field showSearchCommand boolean
---@field bufClosed boolean
---@field highlightResults FileResults
---@field highlightRegions LangRegions
---@field normalModeSearch boolean
---@field searchDisabled boolean
---@field previousInputValues { [string]: string }

---@class GrugFarAction
---@field text string
---@field keymap KeymapDef
---@field description? string
---@field action? fun()

---@class GrugFarContext
---@field count integer
---@field options GrugFarOptions
---@field namespace integer
---@field locationsNamespace integer
---@field resultListNamespace integer
---@field historyHlNamespace integer
---@field helpHlNamespace integer
---@field augroup integer
---@field extmarkIds {[string]: integer}
---@field state GrugFarState
---@field prevWin? integer
---@field prevBufName? string
---@field prevBufFiletype? string
---@field actions GrugFarAction[]
---@field engine GrugFarEngine
---@field replacementInterpreter? GrugFarReplacementInterpreter
---@field fileIconsProvider? FileIconsProvider

---@class VisualSelectionInfo
---@field file_name string
---@field lines string[]
---@field start_col integer
---@field start_row integer
---@field end_col integer
---@field end_row integer
