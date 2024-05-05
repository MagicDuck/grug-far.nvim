local M = {}
M.ansi_color_ending = '[0m'
M.rg_colors = {
  match = {
    rgb = '0,0,0',
    ansi = '[38;2;0;0;0m',
    hl = 'resultsMatch'
  },
  path = {
    rgb = '0,0,1',
    ansi = '[38;2;0;0;1m',
    hl = 'resultsPath'
  },
  line = {
    rgb = '0,0,2',
    ansi = '[38;2;0;0;2m',
    hl = 'resultsLineNo'
  },
}

return M
