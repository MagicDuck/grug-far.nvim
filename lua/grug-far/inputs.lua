local M = {}

---@enum InputNames
M.InputNames = {
  search = 'search',
  replacement = 'replacement',
  filesFilter = 'filesFilter',
  flags = 'flags',
  paths = 'paths',
}

--- fills in given input
---@param context GrugFarContext
---@param buf integer
---@param name InputNames
---@param value string?
---@param clearOld boolean?
local function fillInput(context, buf, name, value, clearOld)
  if not value and not clearOld then
    return
  end

  local extmarkId = context.extmarkIds[name]
  local inputRow
  if extmarkId then
    inputRow = unpack(vim.api.nvim_buf_get_extmark_by_id(buf, context.namespace, extmarkId, {})) --[[@as integer?]]
  end

  if inputRow then
    local oldValue = context.state.inputs[name]
    local numInputLines = #vim.split(oldValue, '\n')
    vim.api.nvim_buf_set_lines(
      buf,
      inputRow,
      inputRow + numInputLines,
      true,
      vim.split(value or '', '\n')
    )
  end
end

--- fills in inputs with given values
--- if clearOld is true, clear old values even if new value not given
---@param context GrugFarContext
---@param buf integer
---@param values GrugFarPrefills | GrugFarPrefillsOverride
---@param clearOld boolean
function M.fill(context, buf, values, clearOld)
  fillInput(context, buf, M.InputNames.search, values.search, clearOld)
  fillInput(context, buf, M.InputNames.replacement, values.replacement, clearOld)
  fillInput(context, buf, M.InputNames.filesFilter, values.filesFilter, clearOld)
  fillInput(context, buf, M.InputNames.flags, values.flags, clearOld)
  fillInput(context, buf, M.InputNames.paths, values.paths, clearOld)
end

return M
