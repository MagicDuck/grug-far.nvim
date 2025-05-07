local utils = require('grug-far.utils')

--- performs sync for given bufrange
---@param params { bufrange: grug.far.VisualSelectionInfo, changes: grug.far.ChangedFile, on_done: fun(errorMessage: string?) }
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

  utils.writeInBufrange(bufrange, lines)

  return on_done()
end

return syncBufrange
