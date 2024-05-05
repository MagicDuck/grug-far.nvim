local utils = require('grug-far/utils')

local abortFetch = nil
local function renderResultList(params)
  local on_start = params.on_start
  local on_fetch_chunk = vim.schedule_wrap(params.on_fetch_chunk)
  local on_finish = vim.schedule_wrap(params.on_finish)
  local on_error = vim.schedule_wrap(params.on_error)
  local inputs = params.inputs
  local context = params.context

  if abortFetch then
    abortFetch();
    abortFetch = nil
  end

  on_start()
  abortFetch = context.options.fetchResults({
    inputs = inputs,
    on_fetch_chunk = on_fetch_chunk,
    on_finish = function(isSuccess)
      abortFetch = nil
      on_finish(isSuccess)
    end,
    on_error = on_error
  })
end

local chunk_progress_icons = {
  '󱑖 ', '󱑋 ', '󱑌 ', '󱑍 ', '󱑎 ', '󱑏 ', '󱑐 ', '󱑑 ', '󱑒 ', '󱑓 ', '󱑔 ', '󱑕 '
}
local function getStatusText(s)
  if s.status == 'error' then
    return ' '
  elseif s.status == 'success' then
    return ' '
  elseif s.status == 'fetching_chunk' then
    return chunk_progress_icons[(s.chunk % #chunk_progress_icons) + 1]
  end

  return ''
end

local function getInitialStatus()
  return { status = nil }
end

local function renderHeader(buf, context, headerRow, newStatus)
  if newStatus then
    context.state.status = newStatus
  end

  -- TODO (sbadragan): maybe show some sort of search status in the virt lines ?
  -- like a clock or a checkmark when replacment has been done?
  -- show some sort of total ?
  context.extmarkIds.results_header = vim.api.nvim_buf_set_extmark(buf, context.namespace, headerRow, 0, {
    id = context.extmarkIds.results_header,
    end_row = headerRow,
    end_col = 0,
    virt_lines = {
      { { " 󱎸 ─────────────────────────────────────────────────────────────────────────────── "
      .. getStatusText(context.state.status), 'SpecialComment' } },
    },
    virt_lines_leftcol = true,
    virt_lines_above = true,
    right_gravity = false
  })
end

local function renderResults(params, context)
  local buf = params.buf
  local minLineNr = params.minLineNr
  local inputs = params.inputs

  if context.state.isFirstRender then
    context.state.asyncRenderResultList = utils.debounce(renderResultList, context.options.debounceMs)
    context.state.lastErrorLine = nil
    context.state.lastInputs = nil
    context.state.status = getInitialStatus()
  end

  local headerRow = unpack(context.extmarkIds.results_header and
    vim.api.nvim_buf_get_extmark_by_id(buf, context.namespace, context.extmarkIds.results_header, {}) or {})

  if headerRow == nil or headerRow < minLineNr then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for _ = #lines, minLineNr do
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
    end

    headerRow = minLineNr
  end

  renderHeader(buf, context, headerRow)

  if vim.deep_equal(inputs, context.state.lastInputs) then
    return
  end
  context.state.lastInputs = inputs

  local function updateStatus(newStatus)
    renderHeader(buf, context, headerRow, newStatus)
  end

  -- TODO (sbadragan): print actual rg command being executed for clarity
  -- TODO (sbadragan): figure out how to "commit" the replacement
  -- TODO (sbadragan): highlight the results properly
  context.state.asyncRenderResultList({
    inputs = inputs,
    on_start = function()
      updateStatus(#inputs.search > 0 and { status = 'fetching_chunk', chunk = 1 } or getInitialStatus())
      -- remove all lines after heading
      vim.api.nvim_buf_set_lines(buf, headerRow, -1, false, { "" })
      context.state.lastErrorLine = headerRow + 1
    end,
    on_fetch_chunk = function(data)
      updateStatus({
        status = 'fetching_chunk',
        chunk = context.state.status.chunk and context.state.status.chunk + 1 or
          2
      })

      -- write colorized output to buffer
      local lastline = vim.api.nvim_buf_line_count(buf)
      -- TODO (sbadragan): remmmove?
      -- context.baleia.buf_set_lines(buf, lastline, lastline, false, chunk_lines)
      vim.api.nvim_buf_set_lines(buf, lastline, lastline, false, data.lines)

      -- TODO (sbadragan): refactor to func
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
    end,
    on_error = function(err)
      updateStatus({ status = 'error' })
      local err_lines = vim.split(err, '\n')

      local lastErrorLine = context.state.lastErrorLine
      vim.api.nvim_buf_set_lines(buf, lastErrorLine, lastErrorLine, false, err_lines)

      for i = lastErrorLine, lastErrorLine + #err_lines do
        vim.api.nvim_buf_add_highlight(buf, context.namespace, 'DiagnosticError', i, 0, -1)
      end
      lastErrorLine = lastErrorLine + #err_lines
    end,
    on_finish = function(isSuccess)
      updateStatus({ status = isSuccess and 'success' or 'error' })
    end,
    context = context
  })
end

return renderResults
