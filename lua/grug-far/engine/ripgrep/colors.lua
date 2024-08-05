local ResultHighlightType = require('grug-far.engine').ResultHighlightType

local M = {}
M.ansi_color_ending = '[0m'
M.rg_colors = {
  match = {
    rgb = '0,0,0',
    ansi = '[38;2;0;0;0m',
    hl = 'GrugFarResultsMatch',
    hl_type = ResultHighlightType.Match,
  },
  path = {
    rgb = '0,0,1',
    ansi = '[38;2;0;0;1m',
    hl = 'GrugFarResultsPath',
    hl_type = ResultHighlightType.FilePath,
  },
  line = {
    rgb = '0,0,2',
    ansi = '[38;2;0;0;2m',
    hl = 'GrugFarResultsLineNo',
    hl_type = ResultHighlightType.LineNumber,
  },
  column = {
    rgb = '0,0,3',
    ansi = '[38;2;0;0;3m',
    hl = 'GrugFarResultsLineColumn',
    hl_type = ResultHighlightType.ColumnNumber,
  },
}

return M
