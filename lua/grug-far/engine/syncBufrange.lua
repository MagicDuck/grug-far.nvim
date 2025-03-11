--- performs sync for given bufrange
---@param params { bufrange: VisualSelectionInfo, changes: ChangedFile, on_done: fun(errorMessage: string?) }
local function syncBufrange(params)
  local changes = params.changes
  local on_done = params.on_done
  local bufrange = params.bufrange

  local changedLines = changes.changedLines
  local lines = vim.deepcopy(bufrange.lines)
  for i = 1, #changedLines do
    local changedLine = changedLines[i]
    local lnum = changedLine.lnum - bufrange.start_row + 1
    if not lines[lnum] then
      return on_done(
        'Buffer was changed and does not have edited row anymore: line '
          .. changedLine.lnum
          .. ' in '
          .. bufrange.file_name
      )
    end

    lines[lnum] = changedLine.newLine
  end

  local buf = vim.fn.bufnr(bufrange.file_name)
  vim.api.nvim_buf_set_text(
    buf,
    bufrange.start_row - 1,
    bufrange.start_col - 1,
    bufrange.end_row - 1,
    bufrange.end_col < 0 and bufrange.end_col or bufrange.end_col - 1,
    lines
  )
end

return syncBufrange
