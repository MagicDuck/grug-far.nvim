local M = {}

function M.appendResultsChunk(buf, context, data)
  -- add text
  local lastline = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, lastline, lastline, false, data.lines)

  -- add highlights
  for i = 1, #data.highlights do
    local highlight = data.highlights[i]
    for j = highlight.start_line, highlight.end_line do
      vim.api.nvim_buf_add_highlight(buf, context.namespace, highlight.hl, lastline + j,
        j == highlight.start_line and highlight.start_col or 0,
        j == highlight.end_line and highlight.end_col or -1)
    end
  end

  -- compute result locations based on highlights and add location marks
  -- those are used for actions like quickfix list and go to location
  local resultsLocations = context.state.resultsLocations
  local resultLocationByExtmarkId = context.state.resultLocationByExtmarkId
  local lastLocation = resultsLocations[#resultsLocations]
  for i = 1, #data.highlights do
    local highlight = data.highlights[i]
    local hl = highlight.hl
    local line = data.lines[highlight.start_line + 1]

    if hl == 'GrugFarResultsPath' then
      lastLocation = { filename = string.sub(line, highlight.start_col + 1, highlight.end_col + 1) }
      table.insert(resultsLocations, lastLocation)

      local markId = vim.api.nvim_buf_set_extmark(buf, context.locationsNamespace, lastline + highlight.start_line, 0, {})
      resultLocationByExtmarkId[markId] = { filename = lastLocation.filename }
    elseif hl == 'GrugFarResultsLineNo' then
      -- omit ending ':'
      lastLocation.lnum = tonumber(string.sub(line, highlight.start_col + 1, highlight.end_col))
    elseif hl == 'GrugFarResultsLineColumn' and not lastLocation.col then
      -- omit ending ':', use first match on that line
      lastLocation.col = tonumber(string.sub(line, highlight.start_col + 1, highlight.end_col))

      local markId = vim.api.nvim_buf_set_extmark(buf, context.locationsNamespace, lastline + highlight.start_line, 0, {})
      resultLocationByExtmarkId[markId] = lastLocation
    end
  end
end

-- note: row is zero-based
function M.getClosestResultLocation(row, buf, context)
  local currentRow = row
  while currentRow > context.state.headerRow do
    local marks = vim.api.nvim_buf_get_extmarks(buf, context.locationsNamespace,
      { currentRow, 0 }, { currentRow, 0 }, { limit = 1 })
    if #marks > 0 then
      local mark = marks[1]
      local location = context.state.resultLocationByExmarkId[mark.extmark_id]
      if location then
        return location
      end
    end
    currentRow = currentRow - 1
  end

  return nil
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

  vim.api.nvim_buf_clear_namespace(buf, context.locationsNamespace, 0, -1)
  context.state.resultLocationByExtmarkId = {}
  context.state.resultsLocations = {}
end

return M
