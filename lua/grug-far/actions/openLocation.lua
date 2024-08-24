local resultsList = require('grug-far/render/resultsList')

--- gets result location that we should open and row in buffer where it is referenced
---@param buf integer
---@param context GrugFarContext
---@param cursor_row integer
---@param increment -1 | 1 | nil
---@param count integer?
---@return ResultLocation?, integer?
local function getLocation(buf, context, cursor_row, increment, count)
  if increment then
    local start_location = resultsList.getResultLocation(cursor_row - 1, buf, context)

    local num_lines = vim.api.nvim_buf_line_count(buf)
    for i = cursor_row + increment, increment > 0 and num_lines or 1, increment do
      local location = resultsList.getResultLocation(i - 1, buf, context)
      if
        location
        and location.lnum
        and not (
          start_location
          and location.filename == start_location.filename
          and location.lnum == start_location.lnum
        )
      then
        return location, i
      end
    end
  else
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
  end
end

--- opens location at current cursor line (if there is one) in previous window
--- if count > 0 given, it will use the result location with that number instead
--- if increment is given, it will use the first location that is at least <increment> away from the current line
---@param params { buf: integer, context: GrugFarContext, increment: -1 | 1 | nil, count: number? }
local function open(params)
  local buf = params.buf
  local context = params.context
  local increment = params.increment
  local count = params.count or 0
  local grugfar_win = vim.fn.bufwinid(buf)

  local cursor_row = unpack(vim.api.nvim_win_get_cursor(grugfar_win))
  local location, row = getLocation(buf, context, cursor_row, increment, count)

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
end

return open
