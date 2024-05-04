local function renderInput(params, context)
  local buf = params.buf
  local lineNr = params.lineNr
  local extmarkName = params.extmarkName
  local label_virt_lines = params.label_virt_lines
  local placeholder_virt_text = params.placeholder_virt_text

  -- TODO (sbadragan): render placeholder help text only when line empty
  local line = unpack(vim.api.nvim_buf_get_lines(buf, lineNr, lineNr + 1, false))
  if line == nil then
    vim.api.nvim_buf_set_lines(buf, lineNr, lineNr, false, { "" })
    line = ''
  end

  if label_virt_lines then
    local labelExtmarkName = extmarkName .. "_label"
    context.extmarkIds[labelExtmarkName] = vim.api.nvim_buf_set_extmark(buf, context.namespace, lineNr, 0, {
      id = context.extmarkIds[labelExtmarkName],
      end_row = lineNr,
      end_col = 0,
      virt_lines = label_virt_lines,
      virt_lines_leftcol = true,
      virt_lines_above = true,
      right_gravity = false
    })
  end

  if placeholder_virt_text then
    local placeholderExtmarkName = extmarkName .. "_placeholder"
    if #line == 0 then
      context.extmarkIds[placeholderExtmarkName] = vim.api.nvim_buf_set_extmark(buf, context.namespace, lineNr, 0, {
        id = context.extmarkIds[placeholderExtmarkName],
        end_row = lineNr,
        end_col = 0,
        virt_text = placeholder_virt_text,
        virt_text_pos = 'overlay'
      })
    elseif context.extmarkIds[placeholderExtmarkName] then
      vim.api.nvim_buf_del_extmark(buf, context.namespace, context.extmarkIds[placeholderExtmarkName])
      context.extmarkIds[placeholderExtmarkName] = nil
    end
  end

  return line
end

return renderInput
