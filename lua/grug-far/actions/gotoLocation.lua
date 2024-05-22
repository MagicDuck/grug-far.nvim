local resultsList = require('grug-far/render/resultsList')

--- opens location at current cursor line (if there is one) in previous window
--- that is the window user was in before creating the grug-far split window
---@param params { buf: integer, context: GrugFarContext }
local function gotoLocation(params)
  local buf = params.buf
  local context = params.context

  local cursor_row = unpack(vim.api.nvim_win_get_cursor(0))
  local location = resultsList.getResultLocation(cursor_row - 1, buf, context)
  if not location then
    return
  end

  if context.prevWin ~= nil then
    vim.fn.win_gotoid(context.prevWin)
  end
  vim.api.nvim_command([[execute "normal! m` "]])
  vim.cmd('e ' .. vim.fn.fnameescape(location.filename))
  vim.api.nvim_win_set_cursor(0, { location.lnum or 1, location.col and location.col - 1 or 0 })
end

return gotoLocation
