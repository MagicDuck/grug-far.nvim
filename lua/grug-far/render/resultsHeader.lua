local opts = require('grug-far/opts')

--- gets status text
---@param context GrugFarContext
---@return string | nil
local function getStatusText(context)
  local status = context.state.status
  if status == 'error' then
    return opts.getIcon('resultsStatusError', context)
  elseif status == 'success' then
    return opts.getIcon('resultsStatusSuccess', context)
  elseif status == 'progress' then
    local spinnerStates = context.options.spinnerStates
    if spinnerStates then
      local progressCount = context.state.progressCount or 0
      return spinnerStates[(progressCount % #spinnerStates) + 1]
    else
      return ''
    end
  end

  return opts.getIcon('resultsStatusReady', context)
end

--- gets separator line
---@param context GrugFarContext
---@return string
local function getSeparator(context)
  -- note: use a large number to ensure it's always > window width
  local separatorLine = context.options.resultsSeparatorLineChar:rep(400)
  return ' '
    .. (getStatusText(context) or '')
    .. ' '
    .. opts.getIcon('resultsEngineLeft', context)
    .. ' '
    .. context.engine.type
    .. ' '
    .. opts.getIcon('resultsEngineRight', context)
    .. separatorLine
end

--- render stats information line
---@param buf integer
---@param context GrugFarContext
---@param headerRow integer
local function renderInfoLine(buf, context, headerRow)
  local virt_texts = {}

  local stats = context.state.stats
  if stats and stats.matches > 0 then
    table.insert(virt_texts, {
      ' ' .. stats.matches .. ' matches in ' .. stats.files .. ' files' .. ' ',
      'GrugFarResultsStats',
    })
  end

  local actionMessage = context.state.actionMessage
  if actionMessage then
    local icon = opts.getIcon('resultsActionMessage', context) or ' '
    table.insert(virt_texts, { icon .. actionMessage, 'GrugFarResultsActionMessage' })
  end

  if #virt_texts > 0 then
    context.extmarkIds.results_info_line =
      vim.api.nvim_buf_set_extmark(buf, context.namespace, headerRow, 0, {
        id = context.extmarkIds.results_info_line,
        end_row = headerRow,
        end_col = 0,
        virt_lines = { virt_texts },
        virt_lines_leftcol = true,
        virt_lines_above = true,
        right_gravity = false,
      })
  elseif context.extmarkIds.results_info_line then
    vim.api.nvim_buf_del_extmark(buf, context.namespace, context.extmarkIds.results_info_line)
    context.extmarkIds.results_info_line = nil
  end
end

---@param buf integer
---@param context GrugFarContext
local function renderResultsHeader(buf, context)
  local headerRow = context.state.headerRow

  context.extmarkIds.results_header =
    vim.api.nvim_buf_set_extmark(buf, context.namespace, headerRow, 0, {
      id = context.extmarkIds.results_header,
      end_row = headerRow,
      end_col = 0,
      virt_lines = {
        { { getSeparator(context), 'GrugFarResultsHeader' } },
      },
      virt_lines_leftcol = true,
      virt_lines_above = true,
      right_gravity = false,
    })

  renderInfoLine(buf, context, headerRow)
end

return renderResultsHeader
