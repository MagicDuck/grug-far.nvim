local sync = require('grug-far.actions.sync')
local openLocation = require('grug-far.actions.openLocation')
local resultsList = require('grug-far.render.resultsList')
local gotoMatch = require('grug-far.actions.gotoMatch')
local utils = require('grug-far.utils')

--- gets adjacent location
---@param buf integer
---@param context grug.far.Context
---@param cursor_row integer
---@param increment -1 | 1
---@return grug.far.ResultLocation?, integer?
local function getAdjacentLocation(buf, context, cursor_row, increment)
  local num_lines = vim.api.nvim_buf_line_count(buf)
  for i = cursor_row + increment, increment > 0 and num_lines or 1, increment do
    local location = resultsList.getResultLocation(i - 1, buf, context)
    if location then
      return location, i
    end
  end

  return nil, nil
end

--- gets 1-based range of lines that we have to sync
---@param buf integer
---@param context grug.far.Context
---@param cursor_row integer
---@param start_location grug.far.ResultLocation
---@return integer, integer
local function getSyncRange(buf, context, cursor_row, start_location)
  local startRow = cursor_row
  local endRow = cursor_row
  local aboveLocation, aboveLocationRow = getAdjacentLocation(buf, context, cursor_row, -1)
  if aboveLocation and aboveLocation.lnum and aboveLocation.lnum == start_location.lnum then
    startRow = aboveLocationRow --[[ @as integer]]
  end

  local belowLocation, belowLocationRow = getAdjacentLocation(buf, context, cursor_row, 1)
  if belowLocation and belowLocation.lnum and belowLocation.lnum == start_location.lnum then
    endRow = belowLocationRow --[[ @as integer]]
  end

  return startRow, endRow
end

--- gets 1-based range of lines that we have to delete
---@param buf integer
---@param context grug.far.Context
---@param start_location grug.far.ResultLocation
---@param syncStartRow integer
---@param syncEndRow integer
---@param newLocationRow integer
---@return integer, integer
local function getDeleteRange(
  buf,
  context,
  start_location,
  syncStartRow,
  syncEndRow,
  newLocationRow
)
  local startRow = syncStartRow
  local endRow = syncEndRow

  local newLocation = resultsList.getResultLocation(newLocationRow - 1, buf, context) --[[ @as grug.far.ResultLocation ]]
  local aboveLocation, aboveLocationRow = getAdjacentLocation(buf, context, startRow, -1)
  local belowLocation = getAdjacentLocation(buf, context, endRow, 1)

  -- extend range to new cursor
  if newLocationRow < startRow then
    startRow = newLocationRow + 1
  end

  if newLocationRow > endRow then
    endRow = newLocationRow - 1
  end

  -- adjust range to respect file boundaries
  if newLocation.filename ~= start_location.filename then
    if newLocationRow < syncStartRow then
      startRow = syncStartRow
    end
    if newLocationRow > syncEndRow then
      endRow = syncEndRow
    end
  end

  -- delete file group if sync range is last thing left inside
  local isLast = aboveLocation
    and aboveLocation.filename == start_location.filename
    and not aboveLocation.lnum
    and ((not belowLocation) or belowLocation.filename ~= start_location.filename)
  if isLast then
    -- note: include empty line before
    local fileGroupStartRow = aboveLocationRow - 1 --[[ @as integer]]
    local fileGroupEndRow = syncEndRow

    if fileGroupStartRow < startRow then
      startRow = fileGroupStartRow
    end
    if fileGroupEndRow > endRow then
      endRow = fileGroupEndRow
    end
  end

  return startRow, endRow
end

--- apply change at current line, optionally remove it from buffer and open location of next/prev change
---@param params { buf: integer, context: grug.far.Context, increment: -1 | 1, open_location?: boolean, remove_synced?: boolean, notify?: boolean }
local function applyChange(params)
  local buf = params.buf
  local context = params.context
  local increment = params.increment
  local grugfar_win = vim.fn.bufwinid(buf)

  local initial_cursor_row = unpack(vim.api.nvim_win_get_cursor(grugfar_win))
  local start_location = resultsList.getResultLocation(initial_cursor_row - 1, buf, context)
  -- make sure we are on a match
  if not (start_location and start_location.lnum) then
    return
  end

  utils.convertAnyScratchBufToRealBuf()

  gotoMatch({ buf = buf, context = context, increment = increment, includeUncounted = true })
  if params.open_location ~= false then
    openLocation({ buf = buf, context = context, useScratchBuffer = false })
  end
  local new_cursor_row = unpack(vim.api.nvim_win_get_cursor(grugfar_win))
  local syncStartRow, syncEndRow = getSyncRange(buf, context, initial_cursor_row, start_location)

  sync({
    buf = params.buf,
    context = context,
    startRow = syncStartRow - 1,
    endRow = syncEndRow - 1,
    shouldNotifyOnComplete = params.notify == true,
    on_success = function()
      if params.remove_synced ~= false then
        local delStartRow, delEndRow =
          getDeleteRange(buf, context, start_location, syncStartRow, syncEndRow, new_cursor_row)
        vim.api.nvim_buf_set_lines(buf, delStartRow - 1, delEndRow, true, {})
      end
    end,
  })
end

return applyChange
