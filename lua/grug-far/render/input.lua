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
  local minLineNr = params.lineNr
  local extmarkName = params.extmarkName
  local prevExtmarkName = params.prevExtmarkName
  local nextExtmarkName = params.nextExtmarkName
  local label = params.label
  local placeholder = params.placeholder
  local icon = opts.getIcon(params.icon, context) or ''

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

  P({ currentStartRow = currentStartRow, currentEndRow = currentEndRow, extmarkName = extmarkName })
  -- if currentStartRow > currentEndRow or #input_lines == 0 then
  --   vim.api.nvim_buf_set_lines(buf, currentStartRow, currentStartRow, false, { '' })
  --
  --   if nextExtmarkName and #input_lines > 0 then
  --     context.extmarkIds[nextExtmarkName] =
  --       vim.api.nvim_buf_set_extmark(buf, context.namespace, currentStartRow + 1, 0, {
  --         id = context.extmarkIds[nextExtmarkName],
  --         end_row = currentStartRow + 1,
  --         end_col = 0,
  --         virt_lines = {
  --           { { ' ' .. icon .. label, 'GrugFarInputLabel' } },
  --         },
  --         virt_lines_leftcol = true,
  --         virt_lines_above = true,
  --         right_gravity = false,
  --       })
  --   end
  --
  --   input_lines = { '' }
  -- end

  context.extmarkIds[extmarkName] =
    vim.api.nvim_buf_set_extmark(buf, context.namespace, currentStartRow, 0, {
      id = context.extmarkIds[extmarkName],
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
    vim.schedule(function()
      local placeholderExtmarkName = extmarkName .. '_placeholder'
      if #input_lines == 1 and #input_lines[1] == 0 then
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
    end)
  end

  return vim.fn.join(input_lines, '\n')
end

return renderInput
