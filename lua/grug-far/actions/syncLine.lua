local sync = require('grug-far/actions/sync')

local function syncLine(params)
  local cursor_row = unpack(vim.api.nvim_win_get_cursor(0)) - 1

  P('executing the syncline action!')
  sync({
    buf = params.buf,
    context = params.context,
    startRow = cursor_row,
    endRow = cursor_row
  })
end

return syncLine
