local history = require('grug-far/history')
local utils = require('grug-far/utils')

--- gets history entry at given 0-based buffer row
---@param historyBuf integer
---@param row integer
---@return HistoryEntry | nil
local function getHistoryEntryAtRow(historyBuf, row)
  local firstEntryRow = nil
  for i = row, 0, -1 do
    local bufline = unpack(vim.api.nvim_buf_get_lines(historyBuf, i, i + 1, false))
    if bufline and #bufline == 0 then
      firstEntryRow = i + 1
      break
    end
  end

  local lastEntryRow = nil
  local lastline = vim.api.nvim_buf_line_count(historyBuf)
  for i = row, lastline, 1 do
    local bufline = unpack(vim.api.nvim_buf_get_lines(historyBuf, i, i + 1, false))
    if i == lastline or (bufline and #bufline == 0) then
      lastEntryRow = i + 1
      break
    end
  end

  if not firstEntryRow or not lastEntryRow or lastEntryRow < firstEntryRow then
    return nil
  end

  local entryLines = vim.api.nvim_buf_get_lines(historyBuf, firstEntryRow, lastEntryRow + 1, false)
  local entry = history.getHistoryEntryFromLines(entryLines)
  return entry
end

--- closes history window
---@param historyWin integer
local function closeHistoryWindow(historyWin)
  vim.api.nvim_win_close(historyWin, true)
end

--- picks history entry based on current line number in history buffer
--- and enters text in FAR buffer
---@param historyWin integer
---@param historyBuf integer
---@param buf integer
local function pickHistoryEntry(historyWin, historyBuf, buf)
  local cursor_row = unpack(vim.api.nvim_win_get_cursor(0)) - 1
  local entry = getHistoryEntryAtRow(historyBuf, cursor_row)
  if not entry then
    return
  end

  local firstInputRow = 2
  local rows = {
    entry.search,
    entry.replacement,
    entry.filesFilter,
    entry.flags,
  }
  vim.api.nvim_buf_set_lines(buf, firstInputRow, firstInputRow + #rows, false, rows)
  closeHistoryWindow(historyWin)
end

--- set up key maps for history buffer
---@param historyWin integer
---@param historyBuf integer
---@param buf integer
---@param context GrugFarContext
local function setupKeymap(historyWin, historyBuf, buf, context)
  local keymaps = context.options.keymaps
  utils.setBufKeymap(
    historyBuf,
    'Grug Far: pick history entry',
    keymaps.pickHistoryEntry,
    function()
      pickHistoryEntry(historyWin, historyBuf, buf)
    end
  )
end

--- creates history window
---@param buf integer
---@param context GrugFarContext
---@return integer historyBuf
local function createHistoryBuffer(buf, context)
  local historyBuf = vim.api.nvim_create_buf(false, true)
  -- TODO (sbadragan): add note to readme
  vim.api.nvim_buf_set_option(historyBuf, 'filetype', 'grug-far-history')

  return historyBuf
end

--- creates history window
---@param buf integer
---@param context GrugFarContext
local function createHistoryWindow(buf, context)
  local historyBuf = createHistoryBuffer(buf, context)
  local width = vim.api.nvim_win_get_width(0) - 2
  local height = vim.api.nvim_win_get_height(0) - 3
  local historyWin = vim.api.nvim_open_win(historyBuf, true, {
    relative = 'win',
    row = 0,
    col = 0,
    width = width,
    height = height,
    border = 'rounded',
    title = 'History',
    title_pos = 'left',
  })
  vim.api.nvim_win_set_option(historyWin, 'number', true)

  local historyFilename = history.getHistoryFilename()
  vim.cmd('e ' .. vim.fn.fnameescape(historyFilename))

  -- delete buffer on window close
  vim.api.nvim_create_autocmd({ 'WinClosed' }, {
    group = context.augroup,
    buffer = historyBuf,
    callback = function()
      vim.api.nvim_buf_delete(historyBuf, { force = true })
    end,
  })

  setupKeymap(historyWin, historyBuf, buf, context)

  return historyWin
end

--- opens history floating window
---@param params { buf: integer, context: GrugFarContext }
local function historyOpen(params)
  local buf = params.buf
  local context = params.context

  createHistoryWindow(buf, context)
end

return historyOpen
