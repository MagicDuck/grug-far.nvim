local opts = require('grug-far/opts')

local function getStatusText(context)
  local status = context.state.status
  if status == 'error' then
    return opts.getIcon('resultsStatusError', context)
  elseif status == 'success' then
    return opts.getIcon('resultsStatusSuccess', context)
  elseif status == 'progress' then
    local progress_icons = opts.getIcon('resultsStatusProgressSeq', context)
    if progress_icons then
      local progressCount = context.state.progressCount or 0
      return progress_icons[(progressCount % #progress_icons) + 1]
    else
      return ''
    end
  end

  return opts.getIcon('resultsStatusReady', context)
end

local DEFAULT_SEPARATOR = '-----------------------------------------------------'
local function getSeparator(context)
  local separatorLine = opts.getIcon('resultsSeparatorLine', context) or DEFAULT_SEPARATOR
  return ' ' .. (getStatusText(context) or '') .. ' ' .. separatorLine
end

local function renderInfoLine(buf, context, headerRow)
  local virt_lines = {}

  local stats = context.state.stats
  if stats and stats.matches > 0 then
    table.insert(virt_lines,
      { { ' ' .. stats.matches .. ' matches in ' .. stats.files .. ' files' .. ' ', context.options.highlights
        .resultsStats } })
  end

  local actionMessage = context.state.actionMessage
  local status = context.state.status
  if actionMessage then
    local icon = opts.getIcon('resultsActionMessage', context) or ' '
    table.insert(virt_lines,
      { { icon .. '' .. actionMessage, status == 'error' and context.options.highlights
      .resultsActionMessageError
      or context.options.highlights.resultsActionMessage } })
  end

  if #virt_lines > 0 then
    context.extmarkIds.results_info_line = vim.api.nvim_buf_set_extmark(buf, context.namespace, headerRow, 0, {
      id = context.extmarkIds.results_info_line,
      end_row = headerRow,
      end_col = 0,
      virt_lines = virt_lines,
      virt_lines_leftcol = true,
      virt_lines_above = true,
      right_gravity = false,
    })
  elseif context.extmarkIds.results_info_line then
    vim.api.nvim_buf_del_extmark(buf, context.namespace, context.extmarkIds.results_info_line)
    context.extmarkIds.results_info_line = nil
  end
end

local function renderResultsHeader(buf, context)
  local headerRow = context.state.headerRow

  context.extmarkIds.results_header = vim.api.nvim_buf_set_extmark(buf, context.namespace, headerRow, 0, {
    id = context.extmarkIds.results_header,
    end_row = headerRow,
    end_col = 0,
    virt_lines = {
      { { getSeparator(context), context.options.highlights.resultsHeader } },
    },
    virt_lines_leftcol = true,
    virt_lines_above = true,
    right_gravity = false
  })

  renderInfoLine(buf, context, headerRow)
end

return renderResultsHeader
