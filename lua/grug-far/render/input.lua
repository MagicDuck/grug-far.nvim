local opts = require('grug-far/opts')

local function renderInput(params, context)
  local buf = params.buf
  local lineNr = params.lineNr
  local extmarkName = params.extmarkName
  local label = params.label
  local placeholder = params.placeholder
  local icon = opts.getIcon(params.icon, context) or ''

  local line = unpack(vim.api.nvim_buf_get_lines(buf, lineNr, lineNr + 1, false))
  if line == nil then
    vim.api.nvim_buf_set_lines(buf, lineNr, lineNr, false, { '' })
    line = ''
  end

  if label then
    local labelExtmarkName = extmarkName .. '_label'
    context.extmarkIds[labelExtmarkName] =
      vim.api.nvim_buf_set_extmark(buf, context.namespace, lineNr, 0, {
        id = context.extmarkIds[labelExtmarkName],
        end_row = lineNr,
        end_col = 0,
        virt_lines = {
          { { ' ' .. icon .. label, 'GrugFarInputLabel' } },
        },
        virt_lines_leftcol = true,
        virt_lines_above = true,
        right_gravity = false,
      })
  end

  if placeholder then
    local placeholderExtmarkName = extmarkName .. '_placeholder'
    if #line == 0 then
      context.extmarkIds[placeholderExtmarkName] =
        vim.api.nvim_buf_set_extmark(buf, context.namespace, lineNr, 0, {
          id = context.extmarkIds[placeholderExtmarkName],
          end_row = lineNr,
          end_col = 0,
          virt_text = {
            { placeholder, 'GrugFarInputPlaceholder' },
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

  return line
end

return renderInput
