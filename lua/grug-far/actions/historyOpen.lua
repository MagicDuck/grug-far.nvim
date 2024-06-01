local renderHelp = require('grug-far/render/help')
local history = require('grug-far/history')
local utils = require('grug-far/utils')
local opts = require('grug-far/opts')

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

---@param historyBuf integer
---@param context GrugFarContext
local function renderHistoryBuffer(historyBuf, context)
  local keymaps = context.options.keymaps

  utils.ensureBufTopEmptyLines(historyBuf, 2)
  renderHelp({
    buf = historyBuf,
    extmarkName = 'historyHelp',
    top_virt_lines = {
      {
        {
          '(edit and save as usual if you need to, make sure to preserve format) ',
          'GrugFarHelpHeader',
        },
      },
    },
    actions = {
      { text = 'Pick Entry', keymap = keymaps.pickHistoryEntry },
      { text = 'Close', keymap = { n = ':q' } },
    },
  }, context)
end

--- creates history window
---@param buf integer
---@param context GrugFarContext
local function createHistoryWindow(buf, context)
  local historyBuf = vim.api.nvim_create_buf(false, true)
  local horizontal_margin = 5
  local vertical_margin = 5
  local width = vim.api.nvim_win_get_width(0) - 2 * horizontal_margin
  local height = vim.api.nvim_win_get_height(0) - 2 * vertical_margin
  local historyWin = vim.api.nvim_open_win(historyBuf, true, {
    relative = 'win',
    row = vertical_margin,
    col = horizontal_margin,
    width = width,
    height = height,
    border = 'rounded',
    title = (opts.getIcon('historyTitle', context) or ' ') .. 'History ',
    title_pos = 'left',
    style = 'minimal',
  })

  local historyFilename = history.getHistoryFilename(context)
  vim.cmd('e ' .. vim.fn.fnameescape(historyFilename))

  -- delete buffer on window close
  vim.api.nvim_create_autocmd({ 'WinClosed' }, {
    group = context.augroup,
    buffer = historyBuf,
    callback = function()
      vim.api.nvim_buf_delete(historyBuf, { force = true })
    end,
  })

  vim.api.nvim_set_option_value('filetype', 'grug-far-history', { buf = historyBuf })
  setupKeymap(historyWin, historyBuf, buf, context)

  local function handleBufferChange()
    renderHistoryBuffer(historyBuf, context)
  end

  -- set up re-render on change
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = context.augroup,
    buffer = historyBuf,
    callback = handleBufferChange,
  })

  -- do the initial render
  vim.schedule(function()
    renderHistoryBuffer(historyBuf, context)
    -- place cursor at first entry
    vim.api.nvim_win_set_cursor(historyWin, { 3, 0 })
  end)

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
