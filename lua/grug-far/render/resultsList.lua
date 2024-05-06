local utils = require('grug-far/utils')
local renderResultsHeader = require('grug-far/render/resultsHeader')
local fetchResults = require('grug-far/rg/fetchResults')

local function asyncFetchResultList(params)
  local on_start = params.on_start
  local on_fetch_chunk = vim.schedule_wrap(params.on_fetch_chunk)
  local on_finish = vim.schedule_wrap(params.on_finish)
  local on_error = vim.schedule_wrap(params.on_error)
  local inputs = params.inputs
  local context = params.context

  if context.state.abortFetch then
    context.state.abortFetch();
    context.state.abortFetch = nil
  end

  vim.schedule(on_start)
  context.state.abortFetch = fetchResults({
    inputs = inputs,
    options = context.options,
    on_fetch_chunk = on_fetch_chunk,
    on_finish = function(isSuccess)
      context.state.abortFetch = nil
      on_finish(isSuccess)
    end,
    on_error = on_error
  })
end

local function bufAppendResultsChunk(buf, context, data)
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

local function bufAppendErrorChunk(buf, context, error)
  local lastErrorLine = context.state.lastErrorLine

  local err_lines = vim.split(error, '\n')
  vim.api.nvim_buf_set_lines(buf, lastErrorLine, lastErrorLine, false, err_lines)

  for i = lastErrorLine, lastErrorLine + #err_lines do
    vim.api.nvim_buf_add_highlight(buf, context.namespace, 'DiagnosticError', i, 0, -1)
  end

  context.state.lastErrorLine = lastErrorLine + #err_lines
end

local function renderResultsList(buf, context, inputs)
  local state = context.state
  state.asyncFetchResultList = state.asyncFetchResultList or
    utils.debounce(asyncFetchResultList, context.options.debounceMs)
  state.asyncFetchResultList({
    inputs = inputs,
    on_start = function()
      state.status = 'progress'
      state.progressCount = 0
      state.stats = { matches = 0, files = 0 }
      renderResultsHeader(buf, context)

      -- remove all lines after heading and add one blank line
      local headerRow = state.headerRow
      vim.api.nvim_buf_set_lines(buf, headerRow, -1, false, { "" })
      state.lastErrorLine = headerRow + 1
    end,
    on_fetch_chunk = function(data)
      state.status = 'progress'
      state.progressCount = state.progressCount + 1
      state.stats = {
        matches = state.stats.matches + data.stats.matches,
        files = state.stats.files + data.stats.files
      }
      renderResultsHeader(buf, context)

      bufAppendResultsChunk(buf, context, data)
    end,
    on_error = function(error)
      state.status = 'error'
      state.progressCount = nil
      state.stats = nil
      renderResultsHeader(buf, context)

      bufAppendErrorChunk(buf, context, error)
    end,
    on_finish = function(status)
      state.status = status
      state.progressCount = nil
      renderResultsHeader(buf, context)
    end,
    context = context
  })
end

return renderResultsList
