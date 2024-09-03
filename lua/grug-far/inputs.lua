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
    local oldNumInputLines = #vim.split(oldValue, '\n')
    local newLines = vim.split(value or '', '\n')
    -- note: we need to adopt this tricky way of inserting the value in order to move
    -- the next inputs extmark position down appropriately
    vim.api.nvim_buf_set_lines(buf, inputRow, inputRow + oldNumInputLines - 1, true, newLines)
    vim.api.nvim_buf_set_lines(buf, inputRow + #newLines, inputRow + #newLines + 1, true, {})
  end
end

--- fills in inputs with given values
--- if clearOld is true, clear old values even if new value not given
---@param context GrugFarContext
---@param buf integer
---@param values GrugFarPrefills | GrugFarPrefillsOverride
---@param clearOld boolean
function M.fill(context, buf, values, clearOld)
  -- filling in reverse order as it's more reliable with the left gravity extmarks
  fillInput(context, buf, M.InputNames.paths, values.paths, clearOld)
  fillInput(context, buf, M.InputNames.flags, values.flags, clearOld)
  fillInput(context, buf, M.InputNames.filesFilter, values.filesFilter, clearOld)
  fillInput(context, buf, M.InputNames.replacement, values.replacement, clearOld)
  fillInput(context, buf, M.InputNames.search, values.search, clearOld)
end

---@class InputMark
---@field start_row integer
---@field start_col integer
---@field end_row integer
---@field name string
---@field value string
---@field details vim.api.keyset.set_extmark

--- gets input mark at given row if there is one there
---@param context GrugFarContext
---@param buf integer
---@param row integer
---@return InputMark?
function M.getInputMarkAtRow(context, buf, row)
  local names = {
    M.InputNames.search,
    M.InputNames.replacement,
    M.InputNames.filesFilter,
    M.InputNames.flags,
    M.InputNames.paths,
  }
  for i, input_name in ipairs(names) do
    local extmarkId = context.extmarkIds[input_name]
    local nextExtmarkId = context.extmarkIds[i < #names and names[i + 1] or 'results_header']

    if extmarkId and nextExtmarkId then
      -- TODO (sbadragan): remove details?
      local start_row, start_col, details = unpack(
        vim.api.nvim_buf_get_extmark_by_id(buf, context.namespace, extmarkId, { details = true })
      )
      local end_boundary_row = unpack(
        vim.api.nvim_buf_get_extmark_by_id(
          buf,
          context.namespace,
          nextExtmarkId,
          { details = true }
        )
      )

      if start_row and end_boundary_row then
        local end_row = end_boundary_row - 1
        local value_lines = vim.api.nvim_buf_get_lines(buf, start_row, end_row + 1, false)
        local value = vim.fn.join(value_lines, '\n')
        if row >= start_row and row <= end_row then
          details.ns_id = nil
          details.id = extmarkId
          ---@cast details vim.api.keyset.set_extmark
          return {
            name = input_name,
            value = value,
            start_row = start_row,
            start_col = start_col,
            end_row = end_row,
            details = details,
          }
        end
      end
    end
  end
end

--- special logic for paste below if in the context of an input
--- if input is empty, prevents extra newline
--- if on last line of input, temporarily adds a newline in order to prevent breaking out of it
---@param context GrugFarContext
---@param buf integer
---@param is_visual? boolean
local function pasteBelow(context, buf, is_visual)
  local win = vim.fn.bufwinid(buf)
  local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(win))
  local mark = M.getInputMarkAtRow(context, buf, cursor_row - 1)
  if not mark then
    return
  end

  local pasteCmd = 'p'
  if not is_visual then
    if mark.end_row > mark.start_row and cursor_row - 1 < mark.end_row then
      -- we have a trailing line, nothing extra to do
      vim.api.nvim_feedkeys('p', 'n', false)
      return
    end

    if mark.value == '' then
      pasteCmd = 'P'
    end
  end

  if pasteCmd == 'p' then
    -- add a blank line at bottom to force paste into the input
    fillInput(context, buf, mark.name, mark.value .. '\n', true)
    vim.api.nvim_win_set_cursor(win, { cursor_row, cursor_col })
  end

  M._pasteBelowCallback = function()
    mark = M.getInputMarkAtRow(context, buf, cursor_row - 1)
    if mark and string.sub(mark.value, -1) == '\n' then
      -- remove blank line
      vim.api.nvim_buf_set_lines(buf, mark.end_row, mark.end_row + 1, true, {})
    end
  end
  local keys = vim.api.nvim_replace_termcodes(
    pasteCmd .. '<esc><cmd>lua require("grug-far/inputs")._pasteBelowCallback()<cr>',
    true,
    false,
    true
  )
  vim.api.nvim_feedkeys(keys, 'n', false)
end

--- special logic for paste above if in the context of an input
--- if input is empty, prevents extra newline
--- if on last line of input in visual mode, temporarily adds a newline in order to prevent breaking out of it
---@param context GrugFarContext
---@param buf integer
---@param is_visual? boolean
local function pasteAbove(context, buf, is_visual)
  local win = vim.fn.bufwinid(buf)
  local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(win))
  local mark = M.getInputMarkAtRow(context, buf, cursor_row - 1)
  if not mark then
    return
  end

  local delete_newline = false

  if not is_visual then
    if mark.end_row > mark.start_row and cursor_row - 1 < mark.end_row then
      -- we have a trailing line, nothing extra to do
      vim.api.nvim_feedkeys('P', 'n', false)
      return
    end

    if mark.value == '' then
      delete_newline = true
    end
  end

  if is_visual then
    -- add a blank line at bottom to force paste into the input
    fillInput(context, buf, mark.name, mark.value .. '\n', true)
    vim.api.nvim_win_set_cursor(win, { cursor_row, cursor_col })
    delete_newline = true
  end

  M._pasteAboveCallback = function()
    mark = M.getInputMarkAtRow(context, buf, cursor_row - 1)
    if mark and delete_newline and string.sub(mark.value, -1) == '\n' then
      -- remove blank line
      vim.api.nvim_buf_set_lines(buf, mark.end_row, mark.end_row + 1, true, {})
    end
  end
  local keys = vim.api.nvim_replace_termcodes(
    'P<esc><cmd>lua require("grug-far/inputs")._pasteAboveCallback()<cr>',
    true,
    false,
    true
  )
  vim.api.nvim_feedkeys(keys, 'n', false)
end

--- special logic for open below in the context of an input
--- if cursor is on last line of input, prevent breaking into next input
---@param context GrugFarContext
---@param buf integer
local function openBelow(context, buf)
  local win = vim.fn.bufwinid(buf)
  local cursor_row = unpack(vim.api.nvim_win_get_cursor(win))
  local mark = M.getInputMarkAtRow(context, buf, cursor_row - 1)
  if not mark then
    return
  end

  local keys = vim.api.nvim_replace_termcodes('A<cr>', true, false, true)
  vim.api.nvim_feedkeys(keys, 'n', false)
end

--- some key rebinds that improve quality of life in the inputs area
---@param context GrugFarContext
---@param buf integer
function M.bindInputSaavyKeys(context, buf)
  vim.api.nvim_buf_set_keymap(buf, 'n', 'p', '', {
    noremap = true,
    nowait = true,
    callback = function()
      pasteBelow(context, buf)
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, 'v', 'p', '', {
    noremap = true,
    nowait = true,
    callback = function()
      pasteBelow(context, buf, true)
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'P', '', {
    noremap = true,
    nowait = true,
    callback = function()
      pasteAbove(context, buf)
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, 'v', 'P', '', {
    noremap = true,
    nowait = true,
    callback = function()
      pasteAbove(context, buf, true)
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, 'n', 'o', '', {
    noremap = true,
    nowait = true,
    callback = function()
      openBelow(context, buf)
    end,
  })
end

return M
