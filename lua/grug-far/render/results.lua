local renderResultsHeader = require('grug-far/render/resultsHeader')

--- ensure a minimum line number so that we don't overlap inputs
---@param buf integer
---@param context GrugFarContext
---@param minLineNr integer
---@return integer headerRow
local function ensureMinLineNr(buf, context, minLineNr)
  local headerRow = nil
  if context.extmarkIds.results_header then
    headerRow = unpack(
      vim.api.nvim_buf_get_extmark_by_id(
        buf,
        context.namespace,
        context.extmarkIds.results_header,
        {}
      )
    )
  end

  if headerRow == nil or headerRow < minLineNr then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for _ = #lines, minLineNr do
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { '' })
    end

    headerRow = minLineNr
  end

  return headerRow --[[@as integer]]
end

---@param params { buf: integer, minLineNr: integer }
---@param context GrugFarContext
local function renderResults(params, context)
  local buf = params.buf
  local minLineNr = params.minLineNr

  context.state.headerRow = ensureMinLineNr(buf, context, minLineNr)

  renderResultsHeader(buf, context)
end

return renderResults
