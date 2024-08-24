local resultsList = require('grug-far/render/resultsList')

--- opens location at current cursor line (if there is one) in previous window
--- Open the location of the buffer in a grufar window
---@param params { buf: integer, context: GrugFarContext }
local function open(params)
  local buf = params.buf
  local context = params.context

  local grugfar_win = vim.api.nvim_get_current_win()
  local cursor_row = unpack(vim.api.nvim_win_get_cursor(0))

  -- TODO (sbadragan): remove this
  P(vim.v.count)
  local location = resultsList.getResultLocation(cursor_row - 1, buf, context)
  if not location then
    return
  end

  if context.prevWin ~= nil then
    vim.fn.win_gotoid(context.prevWin)
  end

  vim.api.nvim_command([[execute "normal! m` "]])

  ---@diagnostic disable-next-line
  local bufnr = vim.fn.bufnr(location.filename)

  if bufnr == -1 then
    vim.api.nvim_command('e ' .. vim.fn.fnameescape(location.filename))
  else
    vim.api.nvim_set_current_buf(bufnr)
  end

  vim.api.nvim_win_set_cursor(0, { location.lnum or 1, location.col and location.col - 1 or 0 })

  vim.api.nvim_set_current_win(grugfar_win)
end

return open
