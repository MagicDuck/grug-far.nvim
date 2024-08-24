local resultsList = require('grug-far/render/resultsList')

--- opens location at current cursor line (if there is one) in previous window
--- if count > 0 given, it will use the result location with that number instead
--- if increment is given, it will use the first location that is at least <increment> away from the current line
---@param params { buf: integer, context: GrugFarContext, increment: -1 | 1 | nil, count: number? }
local function open(params)
  local buf = params.buf
  local context = params.context
  local grugfar_win = vim.api.nvim_get_current_win()

  local increment = params.increment
  local location
  if increment then
    local cursor_row = unpack(vim.api.nvim_win_get_cursor(0))
    local start_location = resultsList.getResultLocation(cursor_row - 1, buf, context)

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local num_lines = #lines
    for i = cursor_row + increment, increment > 0 and num_lines or 1, increment do
      location = resultsList.getResultLocation(i - 1, buf, context)
      if
        location
        and location.lnum
        and not (
          start_location
          and location.filename == start_location.filename
          and location.lnum == start_location.lnum
        )
      then
        vim.api.nvim_win_set_cursor(grugfar_win, { i, 0 })
        break
      end
    end
  else
    local count = params.count or 0
    location = resultsList.getResultLineLocation(buf, context, count)
  end

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
