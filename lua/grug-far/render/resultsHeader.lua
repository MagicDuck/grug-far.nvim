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

local function renderResultsHeader(buf, context, headerRow, newStatus)
  if newStatus then
    context.state.status = newStatus
  end
  if not context.state.status then
    context.state.status = { status = nil }
  end

  -- TODO (sbadragan): show some sort of total matches?
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

return renderResultsHeader
