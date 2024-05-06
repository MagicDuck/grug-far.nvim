local renderResultsHeader = require('grug-far/render/resultsHeader')
local renderResultsList = require('grug-far/render/resultsList')

-- ensure a minimum line number so that we don't overlap inputs
local function ensureMinLineNr(buf, context, minLineNr)
  local headerRow = unpack(context.extmarkIds.results_header and
    vim.api.nvim_buf_get_extmark_by_id(buf, context.namespace, context.extmarkIds.results_header, {}) or {})

  if headerRow == nil or headerRow < minLineNr then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for _ = #lines, minLineNr do
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
    end

    headerRow = minLineNr
  end

  return headerRow
end

local function renderResults(params, context)
  local buf = params.buf
  local minLineNr = params.minLineNr
  local inputs = params.inputs

  context.state.headerRow = ensureMinLineNr(buf, context, minLineNr)

  renderResultsHeader(buf, context)

  -- only re-render list when inputs have changed
  if vim.deep_equal(inputs, context.state.lastInputs) then
    return
  end
  context.state.lastInputs = vim.deepcopy(inputs)

  renderResultsList(buf, context, inputs)
end

return renderResults
