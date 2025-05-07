local renderResultsHeader = require('grug-far.render.resultsHeader')

--- ensure a minimum line number so that we don't overlap inputs
---@param buf integer
---@param context grug.far.Context
---@param initialMinLineNr integer
---@param prevExtmarkName string
---@return integer headerRow
local function ensureMinLineNr(buf, context, initialMinLineNr, prevExtmarkName)
  local last_line = vim.api.nvim_buf_line_count(buf) - 1
  local num_lines_to_add = 0
  if last_line < initialMinLineNr then
    num_lines_to_add = initialMinLineNr - last_line
  end

  local minLineNr = initialMinLineNr

  -- make sure we don't go beyond prev input pos
  if prevExtmarkName and context.extmarkIds[prevExtmarkName] then
    local prevInputRow = unpack(
      vim.api.nvim_buf_get_extmark_by_id(
        buf,
        context.namespace,
        context.extmarkIds[prevExtmarkName],
        {}
      )
    )
    if prevInputRow then
      minLineNr = prevInputRow + 1
    end
  end

  if minLineNr < initialMinLineNr then
    if initialMinLineNr - minLineNr > num_lines_to_add then
      num_lines_to_add = initialMinLineNr - minLineNr
    end
    minLineNr = initialMinLineNr
  end

  local headerRow = minLineNr
  if context.extmarkIds.results_header and prevExtmarkName then
    local row = unpack(
      vim.api.nvim_buf_get_extmark_by_id(
        buf,
        context.namespace,
        context.extmarkIds.results_header,
        {}
      )
    ) --[[@as integer]]
    if row and row > minLineNr then
      headerRow = row
    end
  end

  if num_lines_to_add > 0 then
    local lines = {}
    for _ = 1, num_lines_to_add, 1 do
      table.insert(lines, '')
    end
    vim.api.nvim_buf_set_lines(buf, headerRow, headerRow, false, lines)
  end

  return headerRow
end

---@param params { buf: integer, minLineNr: integer, prevLabelExtmarkName: string }
---@param context grug.far.Context
local function renderResults(params, context)
  local buf = params.buf
  local minLineNr = params.minLineNr

  local headerRow = ensureMinLineNr(buf, context, minLineNr, params.prevLabelExtmarkName)

  renderResultsHeader(buf, context, headerRow)
end

return renderResults
