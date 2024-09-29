local opts = require('grug-far.opts')
local utils = require('grug-far.utils')
local treesitter = require('grug-far.render.treesitter')
local ResultHighlightType = require('grug-far.engine').ResultHighlightType

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
  vim.api.nvim_buf_set_lines(buf, start, ending, strict_indexing, replacement)
  vim.api.nvim_set_option_value('modifiable', isModifiable, { buf = buf })
end

---@class addLocationMarkOpts
---@field sign? ResultHighlightSign
---@field matchLineCount? integer
---@field virt_text? string[][]
---@field virt_text_pos? string

--- adds location mark
---@param buf integer
---@param context GrugFarContext
---@param line integer
---@param end_col integer
---@param options addLocationMarkOpts
---@return integer markId
local function addLocationMark(buf, context, line, end_col, options)
  local sign_text = nil
  if options.sign then
    sign_text = options.sign.text or opts.getIcon(options.sign.icon, context)
  end
  local resultLocationOpts = context.options.resultLocation

  return vim.api.nvim_buf_set_extmark(buf, context.locationsNamespace, line, 0, {
    end_col = end_col,
    end_row = line,
    invalidate = true,
    right_gravity = true,
    sign_text = sign_text,
    sign_hl_group = options.sign and options.sign.hl or nil,
    virt_text = resultLocationOpts.showNumberLabel and options.matchLineCount and {
      {
        resultLocationOpts.numberLabelFormat:format(options.matchLineCount),
        'GrugFarResultsNumberLabel',
      },
    } or options.virt_text,
    virt_text_pos = resultLocationOpts.showNumberLabel
        and options.matchLineCount
        and resultLocationOpts.numberLabelPosition
      or options.virt_text_pos,
  })
end

--- adds highlight result. line is relative to context.state.headerRow
--- in order to support inputs fields with growing number of lines
---@param context GrugFarContext
---@param line integer
---@param loc ResultLocation
local function addHighlightResult(context, line, loc)
  local from = loc.text:match('^(%d+:%d+:)') or loc.text:match('^(%d+%-)')
  if not from then
    return
  end
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
  local res = { row = line, col = #from, end_col = #loc.text, lnum = loc.lnum }
  table.insert(results.lines, res)
end

--- append a bunch of result lines to the buffer
---@param buf integer
---@param context GrugFarContext
---@param data ParsedResultsData
function M.appendResultsChunk(buf, context, data)
  -- add text
  local lastline = vim.api.nvim_buf_line_count(buf)
  setBufLines(buf, lastline, lastline, false, data.lines)
  -- add highlights
  for i = 1, #data.highlights do
    local highlight = data.highlights[i]
    for j = highlight.start_line, highlight.end_line do
      vim.api.nvim_buf_add_highlight(
        buf,
        context.namespace,
        highlight.hl,
        lastline + j,
        j == highlight.start_line and highlight.start_col or 0,
        j == highlight.end_line and highlight.end_col or -1
      )
    end
  end

  -- compute result locations based on highlights and add location marks
  -- those are used for actions like quickfix list and go to location
  local state = context.state
  local resultLocationByExtmarkId = state.resultLocationByExtmarkId
  ---@type ResultLocation?
  local lastLocation = nil

  for i = 1, #data.highlights do
    local highlight = data.highlights[i]
    local hl_type = highlight.hl_type
    local line = data.lines[highlight.start_line + 1]

    if hl_type == ResultHighlightType.FilePath then
      state.resultsLastFilename = string.sub(line, highlight.start_col + 1, highlight.end_col + 1)
      local options = {}
      if context.fileIconsProvider then
        local icon, icon_hl = context.fileIconsProvider:get_icon(state.resultsLastFilename)
        options.virt_text = { { icon .. '  ', icon_hl } }
        options.virt_text_pos = 'inline'
      end

      local markId = addLocationMark(buf, context, lastline + highlight.start_line, #line, options)
      resultLocationByExtmarkId[markId] = { filename = state.resultsLastFilename }
    elseif hl_type == ResultHighlightType.LineNumber then
      -- omit ending ':'
      state.resultMatchLineCount = state.resultMatchLineCount + 1
      lastLocation = { filename = state.resultsLastFilename, count = state.resultMatchLineCount }
      local markId = addLocationMark(
        buf,
        context,
        lastline + highlight.start_line,
        #line,
        { sign = highlight.sign, matchLineCount = state.resultMatchLineCount }
      )
      resultLocationByExtmarkId[markId] = lastLocation

      lastLocation.sign = highlight.sign
      lastLocation.lnum = tonumber(string.sub(line, highlight.start_col + 1, highlight.end_col))
      lastLocation.text = line
      if context.options.resultsHighlight and lastLocation.text then
        addHighlightResult(
          context,
          lastline + highlight.start_line - context.state.headerRow,
          lastLocation
        )
      end
    elseif
      hl_type == ResultHighlightType.ColumnNumber
      and lastLocation
      and not lastLocation.col
    then
      -- omit ending ':', use first match on that line
      lastLocation.col = tonumber(string.sub(line, highlight.start_col + 1, highlight.end_col))
      lastLocation.end_col = highlight.end_col
    elseif hl_type == ResultHighlightType.DiffSeparator then
      addLocationMark(
        buf,
        context,
        lastline + highlight.start_line,
        #line,
        { sign = highlight.sign }
      )
    end
  end
  M.throttledHighlight(buf, context)
end

--- gets result location at given row if available
--- note: row is zero-based
--- additional note: sometimes there are mulltiple marks on the same row, like when lines
--- before this line are deleted, those will be marked as invalid
---@param row integer
---@param buf integer
---@param context GrugFarContext
---@return ResultLocation?
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
      return context.state.resultLocationByExtmarkId[markId]
    end
  end

  return nil
end

--- displays results error
---@param buf integer
---@param context GrugFarContext
---@param error string | nil
function M.setError(buf, context, error)
  M.clear(buf, context)

  local startLine = context.state.headerRow + 1

  local err_lines = vim.split((error and #error > 0) and error or 'Unexpected error!', '\n')
  setBufLines(buf, startLine, startLine, false, err_lines)

  for i = startLine, startLine + #err_lines do
    vim.api.nvim_buf_add_highlight(buf, context.namespace, 'DiagnosticError', i, 0, -1)
  end
end

--- displays results warning
---@param buf integer
---@param context GrugFarContext
---@param warning string | nil
function M.appendWarning(buf, context, warning)
  if not (warning and #warning > 0) then
    return
  end
  local lastline = vim.api.nvim_buf_line_count(buf)

  local warn_lines = vim.split(warning, '\n')
  setBufLines(buf, lastline, lastline, false, warn_lines)

  for i = lastline, lastline + #warn_lines - 1 do
    vim.api.nvim_buf_add_highlight(buf, context.namespace, 'DiagnosticWarn', i, 0, -1)
  end
end

--- iterates over each location in the results list that has text which
--- has been changed by the user
---@param buf integer
---@param context GrugFarContext
---@param startRow integer
---@param endRow integer
---@param callback fun(location: ResultLocation, newLine: string, bufline: string, markId: integer, row: integer, details: vim.api.keyset.extmark_details)
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
        -- ignore ones where user has messed with row:col: or row- prefix as we can't get actual changed text
        local prefix_end = location.end_col and location.end_col + 1 or #tostring(location.lnum) + 1
        local numColPrefix = string.sub(location.text, 1, prefix_end + 1)
        if vim.startswith(bufline, numColPrefix) then
          local newLine = string.sub(bufline, prefix_end + 1, -1)
          ---@cast markId integer
          callback(location, newLine, bufline, markId, row, details)
        end
      end
    end
  end
end

--- marks un-synced lines
---@param buf integer
---@param context GrugFarContext
---@param startRow? integer
---@param endRow? integer
---@param sync? boolean whether to sync with current line contents, this removes indicators
function M.markUnsyncedLines(buf, context, startRow, endRow, sync)
  if not context.engine.isSyncSupported() then
    return
  end
  if
    context.engine.isSearchWithReplacement(context.state.inputs, context.options)
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
        local sign = location.sign or changedSign
        details.ns_id = nil
        ---@cast details vim.api.keyset.set_extmark
        details.id = markId
        details.sign_text = sign and opts.getIcon(sign.icon, context) or nil
        details.sign_hl_group = sign and sign.hl or nil
        vim.api.nvim_buf_set_extmark(buf, context.locationsNamespace, row, 0, details)
      end
    end,
    context.engine.isSearchWithReplacement(context.state.inputs, context.options)
  )
end

--- clears results area
---@param buf integer
---@param context GrugFarContext
function M.clear(buf, context)
  context.state.resultLocationByExtmarkId = {}
  context.state.resultsLastFilename = nil
  context.state.resultMatchLineCount = 0
  context.state.highlightResults = {}
  context.state.highlightRegions = {}
  if context.options.resultsHighlight then
    treesitter.clear(buf, true)
  end
  vim.api.nvim_buf_clear_namespace(buf, context.locationsNamespace, 0, -1)

  -- remove all lines after heading and add one blank line
  local headerRow = context.state.headerRow
  setBufLines(buf, headerRow, -1, false, { '' })
end

--- appends search command to results list
---@param buf integer
---@param context GrugFarContext
---@param rgArgs string[]
function M.appendSearchCommand(buf, context, rgArgs)
  local cmd_path = context.options.engines[context.engine.type].path
  local lastline = vim.api.nvim_buf_line_count(buf)
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

  setBufLines(buf, lastline, lastline, false, lines)
  vim.api.nvim_buf_add_highlight(
    buf,
    context.helpHlNamespace,
    'GrugFarResultsCmdHeader',
    lastline,
    0,
    #header
  )
end

--- force redraws buffer. This is order to apear more responsive to the user
--- and quickly give user feedback as results come in / data is updated
--- note that only the "top" range of lines is redrawn, including a bunch of lines
--- after headerRow so that we immediately get error messages to show up
---@param buf integer
---@param context GrugFarContext
function M.forceRedrawBuffer(buf, context)
  ---@diagnostic disable-next-line
  if vim.api.nvim__redraw then
    ---@diagnostic disable-next-line
    vim.api.nvim__redraw({ buf = buf, flush = true, range = { 0, context.state.headerRow + 100 } })
  end
end

---@param buf number
---@param context GrugFarContext
function M.highlight(buf, context)
  if not context.options.resultsHighlight then
    return
  end
  local regions = context.state.highlightRegions

  -- Process any pending results
  for filename, results in pairs(context.state.highlightResults) do
    results[filename] = nil
    if results.ft then
      local lang = vim.treesitter.language.get_lang(results.ft) or results.ft or 'lua'
      regions[lang] = regions[lang] or {}
      local last_line ---@type number?
      for _, line in ipairs(results.lines) do
        local row = context.state.headerRow + line.row
        local node = { row, line.col, row, line.end_col }
        -- put consecutive lines in the same region
        if line.lnum - 1 ~= last_line then
          table.insert(regions[lang], {})
        end
        last_line = line.lnum
        local last = regions[lang][#regions[lang]]
        table.insert(last, node)
      end
    end
  end
  context.state.highlightResults = {}

  -- Attach the regions to the buffer
  if not vim.tbl_isempty(regions) then
    treesitter.attach(buf, regions)
  end
end

M.throttledHighlight = utils.throttle(M.highlight, 40)
M.throttledForceRedrawBuffer = utils.throttle(M.forceRedrawBuffer, 40)

return M
