local renderResultsHeader = require('grug-far/render/resultsHeader')

--- ensure a minimum line number so that we don't overlap inputs
---@param buf integer
---@param context GrugFarContext
---@param initialMinLineNr integer
---@param prevExtmarkName string
---@return integer headerRow
local function ensureMinLineNr(buf, context, initialMinLineNr, prevExtmarkName)
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

  -- ensure minimal line
  local line = unpack(vim.api.nvim_buf_get_lines(buf, headerRow, headerRow + 1, false))
  if not line then
    vim.api.nvim_buf_set_lines(buf, headerRow, headerRow, false, { '' })
  end

  return headerRow
end

---@param params { buf: integer, minLineNr: integer, prevLabelExtmarkName: string }
---@param context GrugFarContext
local function renderResults(params, context)
  local buf = params.buf
  local minLineNr = params.minLineNr

  context.state.headerRow = ensureMinLineNr(buf, context, minLineNr, params.prevLabelExtmarkName)

  renderResultsHeader(buf, context)
end

return renderResults
