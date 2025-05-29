local resultsList = require('grug-far.render.resultsList')

--- gets result location that we should move to and row in buffer where it is referenced
---@param buf integer
---@param context grug.far.Context
---@param cursor_row integer
---@param increment -1 | 1 | nil
---@param count integer?
---@param includeUncounted boolean?
---@return grug.far.ResultLocation?, integer?
local function getLocation(buf, context, cursor_row, increment, count, includeUncounted)
  if increment then
    local start_location = resultsList.getResultLocation(cursor_row - 1, buf, context)

    local num_lines = vim.api.nvim_buf_line_count(buf)
    for i = cursor_row + increment, increment > 0 and num_lines or 1, increment do
      local location = resultsList.getResultLocation(i - 1, buf, context)
      if
        location
        and location.lnum
        and (includeUncounted or location.count)
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

--- moves to location at current cursor line (if there is one)
--- if count > 0 given, it will use the result location with that number instead
--- if increment is given, it will use the first location that is at least <increment> away from the current line
---@param params { buf: integer, context: grug.far.Context, increment: -1 | 1 | nil, count: number?, includeUncounted: boolean?, wrap: boolean? }
---@return grug.far.ResultLocation?, integer?
local function gotoMatch(params)
  local buf = params.buf
  local context = params.context
  local increment = params.increment
  local includeUncounted = params.includeUncounted
  local count = params.count or 0
  local grugfar_win = vim.fn.bufwinid(buf)
  local wrap = params.wrap

  local cursor_row = unpack(vim.api.nvim_win_get_cursor(grugfar_win))
  local location, row = getLocation(buf, context, cursor_row, increment, count, includeUncounted)

  if not location then
    if wrap and increment == -1 then
      local last_line = vim.api.nvim_buf_line_count(buf)
      location = resultsList.getResultLocation(last_line - 1, buf, context)
      row = last_line
      if not location then
        location, row = getLocation(buf, context, last_line, increment, count, includeUncounted)
      end
    elseif wrap and increment == 1 then
      location, row = getLocation(buf, context, 1, increment, count, includeUncounted)
    end
    if not location then
      return
    end
  end

  if row then
    vim.api.nvim_win_set_cursor(grugfar_win, { row, 0 })
    vim.fn.win_execute(grugfar_win, 'normal! m`')
    if increment ~= nil or count > 0 then
      vim.fn.win_execute(grugfar_win, 'normal! zz')
    end
  end

  return location, row
end

return gotoMatch
