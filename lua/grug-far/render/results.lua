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

local status = getInitialStatus()
local function renderHeader(buf, context, headerRow, newStatus)
  if newStatus then
    status = newStatus
  end

  -- TODO (sbadragan): maybe show some sort of search status in the virt lines ?
  -- like a clock or a checkmark when replacment has been done?
  -- show some sort of total ?
  context.extmarkIds.results_header = vim.api.nvim_buf_set_extmark(buf, context.namespace, headerRow, 0, {
    id = context.extmarkIds.results_header,
    end_row = headerRow,
    end_col = 0,
    virt_lines = {
      { { " 󱎸 ────────────────────────────────────────────────────────── " .. getStatusText(status), 'SpecialComment' } },
    },
    virt_lines_leftcol = true,
    virt_lines_above = true,
    right_gravity = false
  })
end

local asyncRenderResultList = nil
local lastInputs = nil
local lastErrorLine = nil
local function renderResults(params, context)
  local buf = params.buf
  local minLineNr = params.minLineNr
  local inputs = params.inputs

  local headerRow = unpack(context.extmarkIds.results_header and
    vim.api.nvim_buf_get_extmark_by_id(buf, context.namespace, context.extmarkIds.results_header, {}) or {})

  if headerRow == nil or headerRow < minLineNr then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for _ = #lines, minLineNr do
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
    end

    headerRow = minLineNr
  end

  -- TODO (sbadragan): results can move past header when pressing backspace, not sure we can do anything about it
  renderHeader(buf, context, headerRow)

  if vim.deep_equal(inputs, lastInputs) then
    return
  end
  lastInputs = inputs

  local function updateStatus(newStatus)
    renderHeader(buf, context, headerRow, newStatus)
  end

  asyncRenderResultList = asyncRenderResultList or utils.debounce(renderResultList, context.options.debounceMs)
  asyncRenderResultList({
    inputs = inputs,
    on_start = function()
      updateStatus(#inputs.search > 0 and { status = 'fetching_chunk', chunk = 1 } or getInitialStatus())
      -- remove all lines after heading
      vim.api.nvim_buf_set_lines(buf, headerRow, -1, false, {})
      lastErrorLine = headerRow
    end,
    on_fetch_chunk = function(chunk_lines)
      updateStatus({ status = 'fetching_chunk', chunk = status.chunk and status.chunk + 1 or 2 })
      -- TODO (sbadragan): might need some sort of wrapper
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, chunk_lines)
    end,
    on_error = function(err)
      updateStatus({ status = 'error' })
      local err_lines = vim.split(err, '\n')

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
