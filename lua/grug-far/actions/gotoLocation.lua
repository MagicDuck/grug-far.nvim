local resultsList = require('grug-far.render.resultsList')
local utils = require('grug-far.utils')

--- opens location at current cursor line (if there is one) in target window
---@param params { buf: integer, context: grug.far.Context }
local function gotoLocation(params)
  local buf = params.buf
  local context = params.context

  local location = resultsList.getResultLocationAtCursor(buf, context)
  if not location then
    return
  end

  ---@diagnostic disable-next-line
  local bufnr = vim.fn.bufnr(location.filename)
  local targetWin = utils.getOpenTargetWin(context, buf)

  if bufnr == -1 then
    vim.fn.win_execute(
      targetWin,
      'silent! edit ' .. utils.escape_path_for_cmd(location.filename),
      true
    )
  else
    vim.api.nvim_win_set_buf(targetWin, bufnr)
  end

  vim.api.nvim_set_current_win(targetWin)

  vim.api.nvim_win_set_cursor(
    targetWin,
    { location.lnum or 1, location.col and location.col - 1 or 0 }
  )
end

return gotoLocation
