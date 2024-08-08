local opts = require('grug-far/opts')

---@class InputRenderParams
---@field buf integer
---@field lineNr integer
---@field extmarkName string
---@field prevExtmarkName? string
---@field nextExtmarkName? string
---@field label string
---@field placeholder? string | false
---@field icon? string

---@param params InputRenderParams
---@param context GrugFarContext
---@return string textContent
local function renderInput(params, context)
  local buf = params.buf
  -- TODO (sbadragan): rename
  local minLineNr = params.lineNr
  local extmarkName = params.extmarkName
  local labelExtmarkName = extmarkName .. '_label'
  local prevLabelExtmarkName = params.prevExtmarkName and params.prevExtmarkName .. '_label' or nil
  local nextLabelExtmarkName = params.nextExtmarkName and params.nextExtmarkName .. '_label' or nil
  local label = params.label
  local placeholder = params.placeholder
  local icon = opts.getIcon(params.icon, context) or ''

  -- make sure we don't go beyond prev input pos
  if prevLabelExtmarkName then
    local prevInputRow = unpack(
      vim.api.nvim_buf_get_extmark_by_id(
        buf,
        context.namespace,
        context.extmarkIds[prevLabelExtmarkName],
        {}
      )
    )
    if prevInputRow then
      minLineNr = prevInputRow + 1
    end
  end

  -- get current pos
  local currentStartRow = minLineNr
  if context.extmarkIds[labelExtmarkName] then
    local row = unpack(
      vim.api.nvim_buf_get_extmark_by_id(
        buf,
        context.namespace,
        context.extmarkIds[labelExtmarkName],
        {}
      )
    ) --[[@as integer?]]
    if row and row > minLineNr then
      currentStartRow = row
    end
  end

  local currentEndRow = currentStartRow
  -- calculate end by next input start
  if nextLabelExtmarkName and context.extmarkIds[nextLabelExtmarkName] then
    local nextInputRow = unpack(
      vim.api.nvim_buf_get_extmark_by_id(
        buf,
        context.namespace,
        context.extmarkIds[nextLabelExtmarkName],
        {}
      )
    )
    if nextInputRow and nextInputRow > currentStartRow then
      currentEndRow = nextInputRow - 1
    end
  end

  local input_lines =
    unpack(vim.api.nvim_buf_get_lines(buf, currentStartRow, currentEndRow + 1, false))

  -- ensure minimal lines
  if input_lines == nil then
    vim.api.nvim_buf_set_lines(buf, currentStartRow, currentStartRow, false, { '' })
    input_lines = ''
  end

  P({
    extmarkName = extmarkName,
    currentStartRow = currentStartRow,
    currentEndRow = currentEndRow,
    minLineNr = minLineNr,
    input_lines = input_lines,
    lineNr = params.lineNr,
  })

  context.extmarkIds[labelExtmarkName] =
    vim.api.nvim_buf_set_extmark(buf, context.namespace, currentStartRow, 0, {
      id = context.extmarkIds[labelExtmarkName],
      end_row = currentStartRow,
      end_col = 0,
      virt_lines = {
        { { ' ' .. icon .. label, 'GrugFarInputLabel' } },
      },
      virt_lines_leftcol = true,
      virt_lines_above = true,
      right_gravity = false,
    })

  if placeholder then
    local placeholderExtmarkName = extmarkName .. '_placeholder'
    if #input_lines == 0 then
      local ellipsis = ' ...'
      local available_win_width = vim.api.nvim_win_get_width(0) - #ellipsis - 2
      context.extmarkIds[placeholderExtmarkName] =
        vim.api.nvim_buf_set_extmark(buf, context.namespace, currentStartRow, 0, {
          id = context.extmarkIds[placeholderExtmarkName],
          end_row = currentStartRow,
          end_col = 0,
          virt_text = {
            {
              #placeholder <= available_win_width and placeholder
                or placeholder:sub(1, available_win_width) .. ellipsis,
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

  return input_lines
end

return renderInput
