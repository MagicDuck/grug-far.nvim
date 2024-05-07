local M = {}

function M.appendResultsChunk(buf, context, data)
  local lastline = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, lastline, lastline, false, data.lines)

  local hlGroups = context.options.highlights
  for i = 1, #data.highlights do
    local highlight = data.highlights[i]
    local hlGroup = hlGroups[highlight.hl]
    if hlGroup then
      for j = highlight.start_line, highlight.end_line do
        vim.api.nvim_buf_add_highlight(buf, context.namespace, hlGroup, lastline + j,
          j == highlight.start_line and highlight.start_col or 0,
          j == highlight.end_line and highlight.end_col or -1)
      end
    end
  end
end

function M.appendError(buf, context, error)
  local startLine = context.state.headerRow + 1

  local err_lines = vim.split(error, '\n')
  vim.api.nvim_buf_set_lines(buf, startLine, startLine, false, err_lines)

  for i = startLine, startLine + #err_lines do
    vim.api.nvim_buf_add_highlight(buf, context.namespace, 'DiagnosticError', i, 0, -1)
  end
end

return M
