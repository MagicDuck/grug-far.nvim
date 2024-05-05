local progress_icons = {
  '󱑖 ', '󱑋 ', '󱑌 ', '󱑍 ', '󱑎 ', '󱑏 ', '󱑐 ', '󱑑 ', '󱑒 ', '󱑓 ', '󱑔 ', '󱑕 '
}

-- TODO (sbadragan): make configurable
local function getStatusText(s)
  if s.status == 'error' then
    return ' '
  elseif s.status == 'success' then
    return ' '
  elseif s.status == 'progress' then
    return progress_icons[(s.count % #progress_icons) + 1]
  end

  return ''
end

local function renderResultsHeader(buf, context, headerRow)
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

  local stats = context.state.stats
  if stats then
    context.extmarkIds.results_stats = vim.api.nvim_buf_set_extmark(buf, context.namespace, headerRow, 0, {
      id = context.extmarkIds.results_stats,
      end_row = headerRow,
      end_col = 0,
      virt_lines = {
        { { ' ' .. stats.matches .. ' matches in ' .. stats.files .. ' files' .. ' ', 'SpecialComment' } },
      },
      virt_lines_leftcol = true,
      virt_lines_above = true,
      right_gravity = false
    })
  elseif context.extmarkIds.results_stats then
    vim.api.nvim_buf_del_extmark(buf, context.namespace, context.extmarkIds.results_stats)
    context.extmarkIds.results_stats = nil
  end
end

return renderResultsHeader
