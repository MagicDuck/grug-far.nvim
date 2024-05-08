local M = {}

function M.appendResultsChunk(buf, context, data)
  local lastline = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, lastline, lastline, false, data.lines)

  for i = 1, #data.highlights do
    local highlight = data.highlights[i]
    for j = highlight.start_line, highlight.end_line do
      vim.api.nvim_buf_add_highlight(buf, context.namespace, highlight.hl, lastline + j,
        j == highlight.start_line and highlight.start_col or 0,
        j == highlight.end_line and highlight.end_col or -1)
    end
  end

  local resultsLocations = context.state.resultsLocations
  local lastLocation = resultsLocations[#resultsLocations]
  for i = 1, #data.highlights do
    local highlight = data.highlights[i]
    local hl = highlight.hl
    local line = data.lines[highlight.start_line + 1]

    if hl == 'GrugFarResultsPath' then
      lastLocation = { filename = string.sub(line, highlight.start_col + 1, highlight.end_col + 1) }
      table.insert(resultsLocations, lastLocation)
    elseif hl == 'GrugFarResultsLineNo' then
      -- omit ending ':'
      lastLocation.lnum = tonumber(string.sub(line, highlight.start_col + 1, highlight.end_col))
    elseif hl == 'GrugFarResultsLineColumn' then
      -- omit ending ':'
      lastLocation.col = tonumber(string.sub(line, highlight.start_col + 1, highlight.end_col))
    end
  end
end

function M.setError(buf, context, error)
  M.clear(buf, context)

  local startLine = context.state.headerRow + 1

  local err_lines = vim.split((error and #error > 0) and error or 'Unexpected error!', '\n')
  vim.api.nvim_buf_set_lines(buf, startLine, startLine, false, err_lines)

  for i = startLine, startLine + #err_lines do
    vim.api.nvim_buf_add_highlight(buf, context.namespace, 'DiagnosticError', i, 0, -1)
  end
end

function M.clear(buf, context)
  -- remove all lines after heading and add one blank line
  local headerRow = context.state.headerRow
  vim.api.nvim_buf_set_lines(buf, headerRow, -1, false, { "" })

  context.state.resultsLocations = {}
end

return M
