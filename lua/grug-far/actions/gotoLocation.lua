local resultsList = require('grug-far/render/resultsList')

--- gets result location that we should open and row in buffer where it is referenced
---@param buf integer
---@param context GrugFarContext
---@param cursor_row integer
---@param count integer
---@return ResultLocation?, integer?
local function getLocation(buf, context, cursor_row, count)
  if count > 0 then
    for markId, location in pairs(context.state.resultLocationByExtmarkId) do
      if location.count == count then
        local row, _, details = unpack(
          vim.api.nvim_buf_get_extmark_by_id(
            buf,
            context.locationsNamespace,
            markId,
            { details = true }
          )
        )
        if details and not details.invalid then
          ---@cast row integer
          return location, row + 1
        end
      end
    end
  else
    return resultsList.getResultLocation(cursor_row - 1, buf, context), cursor_row
  end

  return nil
end

--- opens location at current cursor line (if there is one) in previous window
--- that is the window user was in before creating the grug-far split window
--- if count > 0 given, it will use the result location with that number instead
---@param params { buf: integer, context: GrugFarContext, count: number? }
local function gotoLocation(params)
  local buf = params.buf
  local context = params.context
  local grugfar_win = vim.fn.bufwinid(buf)

  local cursor_row = unpack(vim.api.nvim_win_get_cursor(grugfar_win))
  local location, row = getLocation(buf, context, cursor_row, params.count or 0)
  if not location then
    return
  end
  if row and row ~= cursor_row then
    vim.api.nvim_win_set_cursor(grugfar_win, { row, 0 })
  end

  vim.api.nvim_command([[execute "normal! m` "]])

  ---@diagnostic disable-next-line
  local bufnr = vim.fn.bufnr(location.filename)
  local targetWin = context.prevWin or grugfar_win

  if bufnr == -1 then
    vim.fn.win_execute(targetWin, 'e ' .. vim.fn.fnameescape(location.filename), true)
  else
    vim.api.nvim_win_set_buf(targetWin, bufnr)
  end

  vim.api.nvim_win_set_cursor(
    targetWin,
    { location.lnum or 1, location.col and location.col - 1 or 0 }
  )

  vim.api.nvim_set_current_win(targetWin)
end

return gotoLocation
