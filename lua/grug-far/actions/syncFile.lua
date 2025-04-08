local sync = require('grug-far.actions.sync')
local resultsList = require('grug-far.render.resultsList')

--- gets boundary location (cursor_row is 1-based)
---@param buf integer
---@param context GrugFarContext
---@param cursor_row integer
---@param increment -1 | 1
---@param filename string?
---@return ResultLocation?, integer?
local function getFileBoundaryLocation(buf, context, cursor_row, increment, filename)
  local num_lines = vim.api.nvim_buf_line_count(buf)
  local _filename = filename
  local boundary_location
  for i = cursor_row + increment, increment > 0 and num_lines or 1, increment do
    local location = resultsList.getResultLocation(i - 1, buf, context)
    if location and location.filename then
      if _filename == nil then
        _filename = location.filename
      elseif _filename ~= location.filename then
        -- found boundary
        return boundary_location, i
      end
      boundary_location = location
    end
  end

  return nil, nil
end

--- gets 1-based range of lines to sync
---@param buf integer
---@param context GrugFarContext
---@param cursor_row integer
---@return integer, integer
local function getSyncRange(buf, context, cursor_row)
  local location = resultsList.getResultLocation(cursor_row - 1, buf, context)
  local filename = location and location.filename or nil

  local start_location, start_row = getFileBoundaryLocation(buf, context, cursor_row, -1, filename)
  if start_location then
    filename = start_location.filename
  end
  if not start_row then
    start_row = cursor_row
  end

  local _, end_row = getFileBoundaryLocation(buf, context, cursor_row, 1, filename)
  if not end_row then
    end_row = cursor_row
  end

  return start_row, end_row
end

--- syncs current result line with original file location
---@param params { buf: integer, context: GrugFarContext }
local function syncFile(params)
  local context = params.context
  local buf = params.buf
  local cursor_row = unpack(vim.api.nvim_win_get_cursor(0))

  local headerRow = resultsList.getHeaderRow(context, buf)
  if cursor_row - 1 <= headerRow then
    return
  end

  local start_row, end_row = getSyncRange(buf, context, cursor_row)

  sync({
    buf = params.buf,
    context = context,
    startRow = start_row - 1,
    endRow = end_row - 1,
  })
end

return syncFile
