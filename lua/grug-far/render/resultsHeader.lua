local opts = require('grug-far.opts')
local inputs = require('grug-far.inputs')

--- gets status text
---@param context grug.far.Context
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
---@param context grug.far.Context
---@return string
local function getSeparator(context)
  -- note: use a large number to ensure it's always > window width
  local separatorLine = context.options.resultsSeparatorLineChar:rep(400)

  local engineInfo = ''
  if context.options.showEngineInfo then
    local engine_type = context.engine.type
    local interpreter_type = context.replacementInterpreter and context.replacementInterpreter.type
      or nil
    if interpreter_type then
      engine_type = engine_type .. ' | ' .. interpreter_type
    end

    engineInfo = (opts.getIcon('resultsEngineLeft', context) or '')
      .. ' '
      .. engine_type
      .. ' '
      .. (context.state.normalModeSearch and '- normal mode search ' or '')
      .. (opts.getIcon('resultsEngineRight', context) or '')
  end

  local statusText = context.options.showStatusIcon and ' ' .. (getStatusText(context) or '') .. ' '
    or ''

  return statusText .. engineInfo .. separatorLine
end

--- gets stats information line
---@param context grug.far.Context
---@return grug.far.VirtText[]
local function getInfoLine(context)
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

  return virt_texts
end

---@param buf integer
---@param context grug.far.Context
---@param row? integer 0-based row, defaults to headerRow
local function renderResultsHeader(buf, context, row)
  local headerRow = row or inputs.getHeaderRow(context, buf)
  local virt_lines = {}
  if context.options.showInputsBottomPadding then
    table.insert(virt_lines, { { '', 'Normal' } })
  end

  table.insert(virt_lines, { { getSeparator(context), 'GrugFarResultsHeader' } })

  local infoLine = context.options.showStatusInfo and getInfoLine(context) or ''
  if #infoLine > 0 then
    table.insert(virt_lines, infoLine)
  end
  -- blank line
  table.insert(virt_lines, { { '', 'Normal' } })

  context.extmarkIds.results_header =
    vim.api.nvim_buf_set_extmark(buf, context.namespace, headerRow, 0, {
      id = context.extmarkIds.results_header,
      end_row = headerRow,
      end_col = 0,
      virt_lines = virt_lines,
      virt_lines_leftcol = true,
      virt_lines_above = true,
      right_gravity = false,
    })

  context.throttledOnStatusChange(buf)
end

return renderResultsHeader
