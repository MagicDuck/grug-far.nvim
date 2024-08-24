local resultsList = require('grug-far/render/resultsList')

--- opens location at current cursor line (if there is one) in previous window
--- that is the window user was in before creating the grug-far split window
---@param params { buf: integer, context: GrugFarContext }
local function gotoLocation(params)
  local buf = params.buf
  local context = params.context

  local location = resultsList.getResultLineLocation(buf, context, vim.v.count)
  if not location then
    return
  end

  if context.prevWin ~= nil then
    vim.fn.win_gotoid(context.prevWin)
  end
  vim.api.nvim_command([[execute "normal! m` "]])
  vim.cmd('e ' .. vim.fn.fnameescape(location.filename))
  pcall(
    vim.api.nvim_win_set_cursor,
    context.prevWin,
    { location.lnum or 1, location.col and location.col - 1 or 0 }
  )
end

return gotoLocation
