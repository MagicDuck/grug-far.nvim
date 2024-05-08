local M = {}
M.ansi_color_ending = '[0m'
M.rg_colors = {
  match = {
    rgb = '0,0,0',
    ansi = '[38;2;0;0;0m',
    hl = 'GrugFarResultsMatch'
  },
  path = {
    rgb = '0,0,1',
    ansi = '[38;2;0;0;1m',
    hl = 'GrugFarResultsPath'
  },
  line = {
    rgb = '0,0,2',
    ansi = '[38;2;0;0;2m',
    hl = 'GrugFarResultsLineNo'
  },
  column = {
    rgb = '0,0,3',
    ansi = '[38;2;0;0;3m',
    hl = 'GrugFarResultsLineColumn'
  },
}

return M
