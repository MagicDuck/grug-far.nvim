local sync = require('grug-far.actions.sync')
local resultsList = require('grug-far.render.resultsList')
local inputs = require('grug-far.inputs')

--- gets boundary location (cursor_row is 1-based)
---@param buf integer
---@param context grug.far.Context
---@param cursor_row integer
---@param cursor_location grug.far.ResultLocation?
---@param increment -1 | 1
---@return grug.far.ResultLocation?, integer?
local function getFileBoundaryLocation(buf, context, cursor_row, cursor_location, increment)
  local num_lines = vim.api.nvim_buf_line_count(buf)
  local boundary_location = cursor_location
  local boundary_row = cursor_row
  for i = cursor_row + increment, increment > 0 and num_lines or 1, increment do
    local location = resultsList.getResultLocation(i - 1, buf, context)
    if location and location.filename then
      if boundary_location == nil or boundary_location.filename == nil then
        boundary_location = location
      elseif boundary_location.filename ~= location.filename then
        -- found neighbor file boundary
        return boundary_location, boundary_row
      end
      boundary_location = location
      boundary_row = i
    end
  end

  return boundary_location, boundary_row
end

--- gets 1-based range of lines to sync
---@param buf integer
---@param context grug.far.Context
---@param cursor_row integer
---@return integer?, integer?
local function getSyncRange(buf, context, cursor_row)
  local cursor_location = resultsList.getResultLocation(cursor_row - 1, buf, context)
  local _, start_row = getFileBoundaryLocation(buf, context, cursor_row, cursor_location, -1)
  local _, end_row = getFileBoundaryLocation(buf, context, cursor_row, cursor_location, 1)

  return start_row, end_row
end

--- syncs current result line with original file location
---@param params { buf: integer, context: grug.far.Context }
local function syncFile(params)
  local context = params.context
  local buf = params.buf
  local cursor_row = unpack(vim.api.nvim_win_get_cursor(0)) --[[@as integer]]

  local headerRow = inputs.getHeaderRow(context, buf)
  if cursor_row - 1 <= headerRow then
    return
  end

  local start_row, end_row = getSyncRange(buf, context, cursor_row)
  if start_row == nil or end_row == nil then
    return
  end

  print('start_row', start_row, 'end_row', end_row)
  sync({
    buf = params.buf,
    context = context,
    startRow = start_row - 1,
    endRow = end_row - 1,
  })
end

return syncFile
