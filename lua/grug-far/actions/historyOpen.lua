local help = require('grug-far.render.help')
local history = require('grug-far.history')
local utils = require('grug-far.utils')
local tasks = require('grug-far.tasks')
local opts = require('grug-far.opts')

--- gets history entry at given 0-based buffer row
---@param historyBuf integer
---@param row integer
---@return grug.far.HistoryEntry | nil
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
---@param context grug.far.Context
local function pickHistoryEntry(historyWin, historyBuf, buf, context)
  local cursor_row = unpack(vim.api.nvim_win_get_cursor(0)) - 1
  local entry = getHistoryEntryAtRow(historyBuf, cursor_row)
  if not entry then
    return
  end

  closeHistoryWindow(historyWin)

  history.fillInputsFromEntry(context, buf, entry)
end

--- set up key maps for history buffer
---@param historyWin integer
---@param historyBuf integer
---@param buf integer
---@param context grug.far.Context
local function setupKeymap(historyWin, historyBuf, buf, context)
  local keymaps = context.options.keymaps
  utils.setBufKeymap(historyBuf, 'Pick history entry', keymaps.pickHistoryEntry, function()
    pickHistoryEntry(historyWin, historyBuf, buf, context)
  end)
end

---@param historyBuf integer
---@param context grug.far.Context
local function renderHistoryBuffer(historyBuf, context)
  local keymaps = context.options.keymaps

  utils.ensureBufTopEmptyLines(historyBuf, 2)

  local top_virt_lines = {
    {
      {
        '(edit and save as usual if you need to, make sure to preserve format) ',
        'GrugFarHelpHeader',
      },
    },
  }

  local help_virt_lines = help.getHelpVirtLines(context, {
    { text = 'Pick Entry', keymap = keymaps.pickHistoryEntry },
  })
  for _, virt_line in ipairs(help_virt_lines) do
    table.insert(top_virt_lines, virt_line)
  end

  context.extmarkIds.historyHelp =
    vim.api.nvim_buf_set_extmark(historyBuf, context.namespace, 0, 0, {
      id = context.extmarkIds.historyHelp,
      virt_text = top_virt_lines[1],
      virt_text_pos = 'overlay',
      virt_lines = vim.list_slice(top_virt_lines, 2),
    })
end

local function highlightHistoryBuffer(historyBuf, context, start_row, end_row)
  local lines = vim.api.nvim_buf_get_lines(historyBuf, start_row, end_row, false)
  vim.api.nvim_buf_clear_namespace(historyBuf, context.historyHlNamespace, start_row, end_row)
  local inputKeys = { 'Engine:', 'Search:', 'Replace:', 'Files Filter:', 'Flags:', 'Paths:' }
  for i, line in ipairs(lines) do
    local highlightedLine = false
    for _, inputKey in ipairs(inputKeys) do
      if not highlightedLine then
        local col_start, col_end = string.find(line, inputKey)
        if col_start == 1 and col_end then
          local l = start_row + i - 1
          vim.hl.range(
            historyBuf,
            context.historyHlNamespace,
            'GrugFarInputLabel',
            { l, col_start - 1 },
            { l, col_end - 1 }
          )
          highlightedLine = true
        end
      end
    end
  end
end

--- creates history window
---@param buf integer
---@param context grug.far.Context
local function createHistoryWindow(buf, context)
  local historyBuf = vim.api.nvim_create_buf(false, true)
  local width = vim.api.nvim_win_get_width(0) - 2
  local height = math.floor(vim.api.nvim_win_get_height(0) * 0.66)
  local historyWinConfig = vim.tbl_extend('force', {
    relative = 'win',
    row = 0,
    col = 2,
    width = width,
    height = height,
    footer = (opts.getIcon('historyTitle', context) or ' ')
      .. 'History (press <:q> or <:bd> to close)',
    footer_pos = 'center',
    border = 'rounded',
    style = 'minimal',
  }, context.options.historyWindow)
  local historyWin = vim.api.nvim_open_win(historyBuf, true, historyWinConfig)

  local historyFilename = history.getHistoryFilename(context)
  vim.cmd('e ' .. utils.escape_path_for_cmd(historyFilename))

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
  vim.api.nvim_buf_attach(historyBuf, false, {
    on_bytes = vim.schedule_wrap(function(_, _, _, start_row, _, _, _, _, _, new_end_row_offset)
      highlightHistoryBuffer(historyBuf, context, start_row, start_row + new_end_row_offset + 1)
    end),
  })

  -- do the initial render
  renderHistoryBuffer(historyBuf, context)
  -- place cursor at first entry
  vim.api.nvim_win_set_cursor(historyWin, { 3, 0 })

  highlightHistoryBuffer(historyBuf, context, 0, -1)

  return historyWin
end

--- opens history floating window
---@param params { buf: integer, context: grug.far.Context }
local function historyOpen(params)
  local buf = params.buf
  local context = params.context

  if tasks.hasActiveTasksWithType(context, 'sync') then
    vim.notify('grug-far: sync in progress', vim.log.levels.INFO)
    return
  end

  if tasks.hasActiveTasksWithType(context, 'replace') then
    vim.notify('grug-far: replace in progress', vim.log.levels.INFO)
    return
  end

  createHistoryWindow(buf, context)
end

return historyOpen
