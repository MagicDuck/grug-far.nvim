local opts = require('grug-far.opts')
local treesitter = require('grug-far.render.treesitter')

---@param params {
--- buf: integer,
--- lineNr: integer,
--- extmarkName: string,
--- prevExtmarkName?: string,
--- nextExtmarkName?: string,
--- label: string,
--- placeholder?: string | false,
--- icon?: string,
--- highlightLang?: string,
--- top_virt_lines?: grug.far.VirtText[][],
--- }
---@param context grug.far.Context
local function renderInput(params, context)
  local buf = params.buf
  local minLineNr = params.lineNr
  local extmarkName = params.extmarkName
  local prevExtmarkName = params.prevExtmarkName
  local nextExtmarkName = params.nextExtmarkName
  local label = params.label
  local top_virt_lines = params.top_virt_lines
  local placeholder = params.placeholder
  local icon = opts.getIcon(params.icon, context) or ''
  local showCompactInputs = context.options.showCompactInputs

  -- make sure we don't go beyond prev input pos
  if prevExtmarkName then
    local prevInputRow = unpack(
      vim.api.nvim_buf_get_extmark_by_id(
        buf,
        context.namespace,
        context.extmarkIds[prevExtmarkName],
        {}
      )
    )
    if prevInputRow then
      minLineNr = prevInputRow + 1
    end
  end

  -- get current pos
  local currentStartRow = minLineNr
  if context.extmarkIds[extmarkName] and prevExtmarkName then
    local row = unpack(
      vim.api.nvim_buf_get_extmark_by_id(
        buf,
        context.namespace,
        context.extmarkIds[extmarkName],
        {}
      )
    ) --[[@as integer?]]
    if row and row > minLineNr then
      currentStartRow = row
    end
  end

  local currentEndRow = nil
  -- calculate end by next input start
  if nextExtmarkName and context.extmarkIds[nextExtmarkName] then
    local nextInputRow = unpack(
      vim.api.nvim_buf_get_extmark_by_id(
        buf,
        context.namespace,
        context.extmarkIds[nextExtmarkName],
        {}
      )
    )
    if nextInputRow then
      currentEndRow = nextInputRow - 1
    end
  end

  -- ensure minimal lines
  if not currentEndRow or currentEndRow < currentStartRow then
    vim.api.nvim_buf_set_lines(buf, currentStartRow, currentStartRow, false, { '' })
    currentEndRow = currentStartRow
  end

  local input_lines = vim.api.nvim_buf_get_lines(buf, currentStartRow, currentEndRow + 1, false)

  local label_virt_lines = top_virt_lines or {}
  if not showCompactInputs then
    table.insert(label_virt_lines, { { ' ' .. icon .. label, 'GrugFarInputLabel' } })
  end
  if showCompactInputs and vim.fn.strwidth(icon) > 2 then
    error(
      'Icons need to be at most 2 characters wide when option showCompactInputs=true. "'
        .. params.icon('" is wider than that!')
    )
  end
  context.extmarkIds[extmarkName] =
    vim.api.nvim_buf_set_extmark(buf, context.namespace, currentStartRow, 0, {
      id = context.extmarkIds[extmarkName],
      end_row = currentStartRow,
      end_col = 0,
      virt_lines = label_virt_lines,
      virt_lines_leftcol = true,
      virt_lines_above = true,
      sign_text = showCompactInputs and icon or nil,
      sign_hl_group = showCompactInputs and 'GrugFarInputLabel' or nil,
      right_gravity = false,
    })

  if params.highlightLang then
    local prev_line =
      unpack(vim.api.nvim_buf_get_lines(buf, currentStartRow - 1, currentStartRow, false))
    local start_col = prev_line and #prev_line or 0
    local last_line = input_lines[#input_lines]
    local end_col = last_line and #last_line or 0
    pcall(treesitter.attach, buf, {
      [params.highlightLang] = {
        { { currentStartRow - 1, start_col, currentEndRow, end_col } },
      },
    }, extmarkName)
  end

  if placeholder or showCompactInputs then
    local placeholderExtmarkName = extmarkName .. '_placeholder'
    if #input_lines == 1 and #input_lines[1] == 0 then
      local ellipsis = ' ...'
      local available_win_width = vim.api.nvim_win_get_width(0) - #ellipsis - 2
      local text = placeholder or ''
      if showCompactInputs then
        text = label .. ' ' .. text
      end
      local newline = opts.getIcon('newline', context)
      if newline then
        text = text:gsub('\\n', newline)
      end
      if #text > available_win_width then
        text = text:sub(1, available_win_width) .. ellipsis
      end

      context.extmarkIds[placeholderExtmarkName] =
        vim.api.nvim_buf_set_extmark(buf, context.namespace, currentStartRow, 0, {
          id = context.extmarkIds[placeholderExtmarkName],
          end_row = currentStartRow,
          end_col = 0,
          virt_text = {
            {
              text,
              'GrugFarInputPlaceholder',
            },
          },
          virt_text_pos = 'overlay',
        })
    elseif context.extmarkIds[placeholderExtmarkName] then
      vim.api.nvim_buf_del_extmark(
        buf,
        context.namespace,
        context.extmarkIds[placeholderExtmarkName]
      )
      context.extmarkIds[placeholderExtmarkName] = nil
    end
  end
end

return renderInput
