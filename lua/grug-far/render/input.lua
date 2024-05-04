local function renderInput(params, context)
  local buf = params.buf
  local lineNr = params.lineNr
  local extmarkName = params.extmarkName
  local label_virt_lines = params.label_virt_lines

  -- TODO (sbadragan): render placeholder help text only when line empty
  local line = unpack(vim.api.nvim_buf_get_lines(buf, lineNr, lineNr + 1, false))
  if line == nil then
    vim.api.nvim_buf_set_lines(buf, lineNr, lineNr, false, { "" })
  end

  if label_virt_lines then
    local labelExtmarkName = extmarkName .. "_label"
    local labelExtmarkPos = context.extmarkIds[labelExtmarkName] and
      vim.api.nvim_buf_get_extmark_by_id(buf, context.namespace, context.extmarkIds[labelExtmarkName], {}) or {}
    if labelExtmarkPos[1] ~= lineNr then
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
  end

  return line or ""
end

return renderInput
