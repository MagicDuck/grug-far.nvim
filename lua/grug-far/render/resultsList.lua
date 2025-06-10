local opts = require('grug-far.opts')
local utils = require('grug-far.utils')
local treesitter = require('grug-far.render.treesitter')
local ResultHighlightType = require('grug-far.engine').ResultHighlightType
local ResultMarkType = require('grug-far.engine').ResultMarkType
local ResultHighlightByType = require('grug-far.engine').ResultHighlightByType
local inputs = require('grug-far.inputs')

local M = {}

--- sets buf lines, even when buf is not modifiable
---@param buf integer
---@param start integer
---@param ending integer
---@param strict_indexing boolean
---@param replacement string[]
local function setBufLines(buf, start, ending, strict_indexing, replacement)
  local isModifiable = vim.api.nvim_get_option_value('modifiable', { buf = buf })
  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })

  -- note: undojoin will fail immediately after an undo
  pcall(vim.cmd.undojoin)
  vim.api.nvim_buf_set_lines(buf, start, ending, strict_indexing, replacement)
  vim.api.nvim_set_option_value('modifiable', isModifiable, { buf = buf })
end

--- adds location mark
---@param buf integer
---@param context grug.far.Context
---@param namespace integer
---@param startLine integer
---@param mark grug.far.ResultMark
---@return integer markId
local function addMark(buf, context, namespace, startLine, mark)
  local sign_text = nil
  if mark.sign then
    sign_text = mark.sign.text or opts.getIcon(mark.sign.icon, context)
  end

  local line = startLine + mark.start_line
  return vim.api.nvim_buf_set_extmark(buf, namespace, line, mark.start_col, {
    end_col = mark.end_col,
    end_row = line,
    invalidate = true,
    right_gravity = true,
    sign_text = sign_text,
    sign_hl_group = mark.sign and mark.sign.hl or nil,
    virt_text = mark.virt_text,
    virt_text_pos = mark.virt_text_pos,
  })
end

--- adds highlight result. line is relative to headerRow
--- in order to support inputs fields with growing number of lines
---@param context grug.far.Context
---@param line integer
---@param end_col integer
---@param loc grug.far.SourceLocation
local function addHighlightResult(context, line, end_col, loc)
  local results = context.state.highlightResults[loc.filename]
  if not results then
    results = {
      lines = {},
      ft = utils.getFileType(loc.filename),
    }
    context.state.highlightResults[loc.filename] = results
  end
  if not results.ft then
    -- we still keep it in results, so that we don't
    -- try to detect the filetype again
    return
  end
  local res = { row = line, col = 0, end_col = end_col, lnum = loc.lnum }
  table.insert(results.lines, res)
end

local function getTrimmedLineMessage(maxLineLength)
  return ' ... (very long line, trimmed to ' .. maxLineLength .. ' chars)'
end

--- adds result text to buffer
---@param buf integer
---@param context grug.far.Context
---@param data grug.far.ParsedResultsData
---@return integer lastline number before adding the text
local function addResultChunkLines(buf, context, data)
  -- trim long lines
  local maxLineLength = context.options.maxLineLength
  if maxLineLength > -1 then
    for i = 1, #data.lines do
      local line = data.lines[i]
      if #line > maxLineLength then
        data.lines[i] = line:sub(1, maxLineLength) .. getTrimmedLineMessage(maxLineLength)
      end
    end
  end

  -- add text
  local headerRow = inputs.getHeaderRow(context, buf)
  local linecount = vim.api.nvim_buf_line_count(buf)
  local lastline = linecount == headerRow + 1 and headerRow or linecount
  setBufLines(buf, lastline, -1, false, data.lines)

  return lastline
end

--- adds result highlights to buffer
---@param buf integer
---@param context grug.far.Context
---@param data grug.far.ParsedResultsData
---@param startLine integer
local function addResultChunkHighlights(buf, context, data, startLine)
  local maxLineLength = context.options.maxLineLength
  for _, highlight in ipairs(data.highlights) do
    for j = highlight.start_line, highlight.end_line do
      if
        maxLineLength > -1
        and j == highlight.start_line
        and highlight.start_col > maxLineLength
      then
        break
      end

      local lineNr = startLine + j
      local start_col = j == highlight.start_line and highlight.start_col or 0

      local end_col = -1
      if j == highlight.end_line then
        end_col = highlight.end_col
        if maxLineLength > -1 then
          end_col = math.min(end_col, maxLineLength)
        end
      else
        if #data.lines[j] > maxLineLength then
          end_col = maxLineLength
        end
      end

      vim.hl.range(
        buf,
        context.resultListNamespace,
        highlight.hl_group,
        { lineNr, start_col },
        { lineNr, end_col }
      )
    end
  end

  if maxLineLength > -1 then
    local trimmedLineMsgLen = #getTrimmedLineMessage(maxLineLength)
    for i = 1, #data.lines do
      local line = data.lines[i]
      if #line > maxLineLength then
        local lineNr = startLine + i - 1
        local start_col = #line - trimmedLineMsgLen
        vim.hl.range(
          buf,
          context.resultListNamespace,
          'GrugFarResultsLongLineStr',
          { lineNr, start_col },
          { lineNr, -1 }
        )
      end
    end
  end
end

--- adds result marks to buffer
---@param buf integer
---@param context grug.far.Context
---@param data grug.far.ParsedResultsData
---@param startLine integer
local function addResultChunkMarks(buf, context, data, startLine)
  local resultLocationByExtmarkId = context.state.resultLocationByExtmarkId
  local headerRow = inputs.getHeaderRow(context, buf)
  local resultLocationOpts = context.options.resultLocation
  local maxLineLength = context.options.maxLineLength
  local window_width = vim.api.nvim_win_get_width(0)

  -- get max line and col len
  local max_line_no_len = {}
  local max_col_no_len = {}
  for _, mark in ipairs(data.marks) do
    if maxLineLength > -1 and mark.end_col > maxLineLength then
      mark.end_col = maxLineLength
      if mark.location then
        mark.location.text = data.lines[mark.start_line + 1]
      end
    end

    if mark.type == ResultMarkType.SourceLocation and mark.location.lnum then
      local filename = mark.location.filename
      local num_len = #tostring(mark.location.lnum)
      local col_len = mark.location.col and #tostring(mark.location.col) or nil
      if not max_line_no_len[filename] or max_line_no_len[filename] < num_len then
        max_line_no_len[filename] = num_len
      end
      if col_len and (not max_col_no_len[filename] or max_col_no_len[filename] < col_len) then
        max_col_no_len[filename] = col_len
      end
    end
  end

  for _, mark in ipairs(data.marks) do
    local namespace = context.resultListNamespace
    if mark.type == ResultMarkType.SourceLocation then
      namespace = context.locationsNamespace
      if context.fileIconsProvider and mark.location.filename and not mark.location.lnum then
        local icon, icon_hl = context.fileIconsProvider:get_icon(mark.location.filename)
        mark.virt_text = { { icon .. '  ', icon_hl } }
        mark.virt_text_pos = 'inline'
      end

      if mark.location.lnum then
        if context.options.resultsHighlight then
          addHighlightResult(
            context,
            startLine + mark.start_line - headerRow,
            #data.lines[mark.start_line + 1],
            mark.location
          )
        end

        local max_line_number_length = max_line_no_len[mark.location.filename]
        local max_column_number_length = max_col_no_len[mark.location.filename] or 0
        mark.virt_text = context.options.lineNumberLabel({
          max_line_number_length = max_line_number_length,
          max_column_number_length = max_column_number_length,
          line_number = mark.location.lnum,
          column_number = mark.location.col,
          is_context = mark.is_context,
        }, context.options)
        local loc = mark.location
        ---@cast loc grug.far.ResultLocation
        loc.max_line_number_length = max_line_number_length
        loc.max_column_number_length = max_column_number_length
        loc.is_context = mark.is_context

        mark.virt_text_pos = 'inline'
      end
    elseif mark.type == ResultMarkType.DiffSeparator then
      local max_line_number_length = max_line_no_len[mark.location.filename]
      local max_column_number_length = max_col_no_len[mark.location.filename] or 0
      mark.virt_text = context.options.lineNumberLabel({
        max_line_number_length = max_line_number_length,
        max_column_number_length = max_column_number_length,
      }, context.options)
      local loc = mark.location
      ---@cast loc grug.far.ResultLocation
      loc.max_line_number_length = max_line_number_length
      loc.max_column_number_length = max_column_number_length

      mark.virt_text_pos = 'inline'
    end

    local markId = addMark(buf, context, namespace, startLine, mark)
    if mark.type == ResultMarkType.SourceLocation then
      local loc = mark.location --[[@as grug.far.ResultLocation]]

      if mark.location.is_counted then
        context.state.resultMatchLineCount = context.state.resultMatchLineCount + 1
        loc.count = context.state.resultMatchLineCount

        if resultLocationOpts.showNumberLabel then
          addMark(buf, context, context.resultListNamespace, startLine, {
            type = ResultMarkType.MatchCounter,
            start_line = mark.start_line,
            start_col = mark.start_col,
            end_line = mark.end_line,
            end_col = mark.end_col,
            virt_text = {
              {
                resultLocationOpts.numberLabelFormat:format(context.state.resultMatchLineCount),
                ResultHighlightByType[ResultHighlightType.NumberLabel],
              },
            },
            virt_text_pos = resultLocationOpts.numberLabelPosition,
          })
        end
      end

      resultLocationByExtmarkId[markId] = loc
    end

    -- concealment for file paths
    if
      mark.type == ResultMarkType.SourceLocation
      and not mark.location.lnum
      and opts.shouldConceal(context.options)
      and context.options.filePathConceal
    then
      local start_col, end_col = context.options.filePathConceal({
        file_path = mark.location.filename,
        window_width = window_width,
      })
      if start_col and end_col then
        local line = startLine + mark.start_line
        start_col = mark.start_col + math.max(0, start_col)
        end_col = math.min(mark.start_col + end_col, mark.end_col)

        vim.api.nvim_buf_set_extmark(buf, context.resultListNamespace, line, start_col, {
          end_col = end_col,
          end_row = line,
          invalidate = true,
          conceal = context.options.filePathConcealChar or ' ',
          hl_group = ResultHighlightByType[ResultHighlightType.FilePath],
        })
      end
    end
  end
end

--- append a bunch of result lines to the buffer
---@param buf integer
---@param context grug.far.Context
---@param data grug.far.ParsedResultsData
function M.appendResultsChunk(buf, context, data)
  local lastline = addResultChunkLines(buf, context, data)
  addResultChunkHighlights(buf, context, data, lastline)
  addResultChunkMarks(buf, context, data, lastline)
end

--- gets result location at given row if available
--- note: row is zero-based
--- additional note: sometimes there are mulltiple marks on the same row, like when lines
--- before this line are deleted, those will be marked as invalid
---@param row integer
---@param buf integer
---@param context grug.far.Context
---@return grug.far.ResultLocation?, vim.api.keyset.get_extmark_item?
function M.getResultLocation(row, buf, context)
  local marks = vim.api.nvim_buf_get_extmarks(
    buf,
    context.locationsNamespace,
    { row, 0 },
    { row, 0 },
    { details = true }
  )

  for _, mark in ipairs(marks) do
    local markId, _, _, details = unpack(mark)
    if not details.invalid then
      return context.state.resultLocationByExtmarkId[markId], mark
    end
  end

  return nil
end

---@param buf integer
---@param context grug.far.Context
---@return grug.far.ResultLocation?, vim.api.keyset.get_extmark_item?
function M.getResultLocationAtCursor(buf, context)
  local grugfar_win = vim.fn.bufwinid(buf)
  local cursor_row = unpack(vim.api.nvim_win_get_cursor(grugfar_win))
  return M.getResultLocation(cursor_row - 1, buf, context)
end

--- displays results error
---@param buf integer
---@param context grug.far.Context
---@param error string | nil
function M.setError(buf, context, error)
  M.clear(buf, context)

  local headerRow = inputs.getHeaderRow(context, buf)
  local startLine = headerRow

  local err_lines = vim.split((error and #error > 0) and error or 'Unexpected error!', '\n')
  setBufLines(buf, startLine, -1, false, err_lines)

  for i = startLine, startLine + #err_lines do
    vim.hl.range(buf, context.resultListNamespace, 'DiagnosticError', { i, 0 }, { i, -1 })
  end
end

--- displays results warning
---@param buf integer
---@param context grug.far.Context
---@param warning string | nil
function M.appendWarning(buf, context, warning)
  if not (warning and #warning > 0) then
    return
  end
  local lastline = vim.api.nvim_buf_line_count(buf)

  local warn_lines = vim.split(warning, '\n')
  setBufLines(buf, lastline, -1, false, warn_lines)

  for i = lastline, lastline + #warn_lines - 1 do
    vim.hl.range(buf, context.resultListNamespace, 'DiagnosticWarn', { i, 0 }, { i, -1 })
  end
end

--- iterates over each location in the results list that has text which
--- has been changed by the user
---@param buf integer
---@param context grug.far.Context
---@param startRow integer
---@param endRow integer
---@param callback fun(location: grug.far.ResultLocation, newLine: string, bufline: string, markId: integer, row: integer, details: vim.api.keyset.extmark_details)
---@param forceChanged? boolean
function M.forEachChangedLocation(buf, context, startRow, endRow, callback, forceChanged)
  local extmarks = vim.api.nvim_buf_get_extmarks(
    buf,
    context.locationsNamespace,
    { startRow, 0 },
    { endRow, -1 },
    { details = true }
  )

  for _, mark in ipairs(extmarks) do
    local markId, row, _, details = unpack(mark)

    -- get the associated location info
    local location = context.state.resultLocationByExtmarkId[markId]
    if (not details.invalid) and location and location.text then
      -- get the current text on row
      local bufline = unpack(vim.api.nvim_buf_get_lines(buf, row, row + 1, false))
      local isChanged = forceChanged or bufline ~= location.text
      if bufline and isChanged then
        ---@cast markId integer
        callback(location, bufline, bufline, markId, row, details)
      end
    end
  end
end

--- marks un-synced lines
---@param buf integer
---@param context grug.far.Context
---@param startRow? integer
---@param endRow? integer
---@param sync? boolean whether to sync with current line contents, this removes indicators
function M.markUnsyncedLines(buf, context, startRow, endRow, sync)
  if not context.engine.isSyncSupported() then
    return
  end
  local _inputs = inputs.getValues(context, buf)
  if
    context.engine.isSearchWithReplacement(_inputs, context.options)
    and context.engine.showsReplaceDiff(context.options)
  then
    return
  end
  if not opts.getIcon('resultsChangeIndicator', context) then
    return
  end
  local changedSign = {
    icon = 'resultsChangeIndicator',
    hl = 'GrugFarResultsChangeIndicator',
  }

  local extmarks = vim.api.nvim_buf_get_extmarks(
    buf,
    context.locationsNamespace,
    { startRow or 0, 0 },
    { endRow or -1, -1 },
    { details = true }
  )
  if #extmarks == 0 then
    return
  end

  -- reset marks
  for _, mark in ipairs(extmarks) do
    local markId, row, _, details = unpack(mark)
    if not details.invalid then
      local location = context.state.resultLocationByExtmarkId[markId]
      if location and location.text then
        ---@cast markId integer
        details.id = markId
        details.sign_text = nil
        details.ns_id = nil
        vim.api.nvim_buf_set_extmark(buf, context.locationsNamespace, row, 0, details)
      end
    end
  end

  -- update the ones that are changed
  M.forEachChangedLocation(
    buf,
    context,
    startRow or 0,
    endRow or -1,
    function(location, _, bufLine, markId, row, details)
      if sync then
        location.text = bufLine
      else
        local sign = changedSign
        details.ns_id = nil
        ---@cast details vim.api.keyset.set_extmark
        details.id = markId
        details.sign_text = sign and opts.getIcon(sign.icon, context) or nil
        details.sign_hl_group = sign and sign.hl or nil
        vim.api.nvim_buf_set_extmark(buf, context.locationsNamespace, row, 0, details)
      end
    end,
    context.engine.isSearchWithReplacement(_inputs, context.options)
  )
end

--- clears results area
---@param buf integer
---@param context grug.far.Context
function M.clear(buf, context)
  context.state.resultLocationByExtmarkId = {}
  context.state.resultMatchLineCount = 0
  context.state.highlightResults = {}
  context.state.highlightRegions = {}
  if context.options.resultsHighlight then
    treesitter.clear(buf, true)
  end
  vim.api.nvim_buf_clear_namespace(buf, context.locationsNamespace, 0, -1)
  vim.api.nvim_buf_clear_namespace(buf, context.resultListNamespace, 0, -1)

  -- remove all lines after heading
  local headerRow = inputs.getHeaderRow(context, buf)
  setBufLines(buf, headerRow, -1, false, { '' })
end

--- appends search command to results list
---@param buf integer
---@param context grug.far.Context
---@param rgArgs string[]
function M.appendSearchCommand(buf, context, rgArgs)
  local headerRow = inputs.getHeaderRow(context, buf)
  local linecount = vim.api.nvim_buf_line_count(buf)
  local lastline = linecount == headerRow + 1 and headerRow or linecount

  local cmd_path = context.options.engines[context.engine.type].path
  local header = 'Search Command:'
  local lines = { header }
  for i, arg in ipairs(rgArgs) do
    local line = vim.fn.shellescape(arg:gsub('\n', '\\n'))
    if i == 1 then
      line = cmd_path .. ' ' .. line
    end
    if i < #rgArgs then
      line = line .. ' \\'
    end
    table.insert(lines, line)
  end
  table.insert(lines, '')
  table.insert(lines, '')

  setBufLines(buf, lastline, -1, false, lines)
  vim.hl.range(
    buf,
    context.helpHlNamespace,
    'GrugFarResultsCmdHeader',
    { lastline, 0 },
    { lastline, #header }
  )
end

--- force redraws buffer. This is order to appear more responsive to the user
--- and quickly give user feedback as results come in / data is updated
--- note that only the "top" range of lines is redrawn, including a bunch of lines
--- after headerRow so that we immediately get error messages to show up
---@param buf integer
---@param context grug.far.Context
function M.forceRedrawBuffer(buf, context)
  ---@diagnostic disable-next-line
  if vim.api.nvim__redraw then
    local headerRow = inputs.getHeaderRow(context, buf)
    ---@diagnostic disable-next-line
    vim.api.nvim__redraw({ buf = buf, flush = true, range = { 0, headerRow + 100 } })
  end
end

---@param buf number
---@param context grug.far.Context
function M.highlight(buf, context)
  if not context.options.resultsHighlight then
    return
  end
  local regions = context.state.highlightRegions
  local headerRow = inputs.getHeaderRow(context, buf)

  -- Process any pending results
  for filename, results in pairs(context.state.highlightResults) do
    results[filename] = nil
    if results.ft then
      local lang = vim.treesitter.language.get_lang(results.ft) or results.ft or 'lua'
      regions[lang] = regions[lang] or {}
      local last_line ---@type number?
      local last_node
      for _, line in ipairs(results.lines) do
        local row = headerRow + line.row

        -- put consecutive lines in the same region
        local is_consecutive = line.lnum - 1 == last_line
        last_line = line.lnum

        if is_consecutive then
          last_node[3] = row
          last_node[4] = line.end_col
        else
          last_node = { row, line.col, row, line.end_col }
          table.insert(regions[lang], { last_node })
        end
      end
    end
  end
  context.state.highlightResults = {}

  -- Attach the regions to the buffer
  if not vim.tbl_isempty(regions) then
    pcall(treesitter.attach, buf, regions)
  end
end

--- re-renders line number at given location
---@param context grug.far.Context
---@param buf integer
---@param loc grug.far.ResultLocation
---@param mark vim.api.keyset.get_extmark_item
---@param is_current_line boolean
function M.rerenderLineNumber(context, buf, loc, mark, is_current_line)
  local markId, start_row, start_col, details = unpack(mark)
  details.ns_id = nil
  ---@cast details vim.api.keyset.set_extmark
  ---@cast markId integer
  details.id = markId
  details.virt_text = context.options.lineNumberLabel({
    max_line_number_length = loc.max_line_number_length,
    max_column_number_length = loc.max_column_number_length,
    line_number = loc.lnum,
    column_number = loc.col,
    is_context = loc.is_context,
    is_current_line = is_current_line,
  }, context.options)
  pcall(
    vim.api.nvim_buf_set_extmark,
    buf,
    context.locationsNamespace,
    start_row,
    start_col,
    details
  )
end

M.throttledForceRedrawBuffer = utils.throttle(M.forceRedrawBuffer, 40)

return M
