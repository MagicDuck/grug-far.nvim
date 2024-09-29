local sync = require('grug-far.actions.sync')

--- syncs current result line with original file location
---@param params { buf: integer, context: GrugFarContext }
local function syncLine(params)
  local context = params.context
  local cursor_row = unpack(vim.api.nvim_win_get_cursor(0)) - 1

  if cursor_row <= context.state.headerRow then
    return
  end

  sync({
    buf = params.buf,
    context = context,
    startRow = cursor_row,
    endRow = cursor_row,
  })
end

return syncLine
