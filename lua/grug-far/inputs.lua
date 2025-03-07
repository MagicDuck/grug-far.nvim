local M = {}

--- gets input lines for given input name
---@param context GrugFarContext
---@param buf integer
---@param name string
---@return string[]
local function getInputLines(context, buf, name)
  local nextExtmarkName = nil
  for i, input in ipairs(context.engine.inputs) do
    if input.name == name then
      local nextInput = context.engine.inputs[i + 1]
      nextExtmarkName = nextInput and nextInput.name or 'results_header'
    end
  end

  if not nextExtmarkName then
    return { '' }
  end

  local startRow =
    unpack(vim.api.nvim_buf_get_extmark_by_id(buf, context.namespace, context.extmarkIds[name], {})) --[[@as integer?]]
  local endRow = unpack(
    vim.api.nvim_buf_get_extmark_by_id(
      buf,
      context.namespace,
      context.extmarkIds[nextExtmarkName],
      {}
    )
  ) --[[@as integer?]]

  if not (startRow and endRow) then
    return { '' }
  end

  return vim.api.nvim_buf_get_lines(buf, startRow, endRow, false)
end

--- fills in given input
---@param context GrugFarContext
---@param buf integer
---@param name string
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
    local oldNumInputLines = #getInputLines(context, buf, name)
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
---@param values GrugFarPrefills
---@param clearOld boolean
function M.fill(context, buf, values, clearOld)
  -- filling in reverse order as it's more reliable with the left gravity extmarks
  context.state.searchDisabled = true
  for i = #context.engine.inputs, 1, -1 do
    local input = context.engine.inputs[i]
    fillInput(context, buf, input.name, values[input.name], clearOld)
  end
  context.state.searchDisabled = false
  vim.schedule(function()
    -- hack to get syntax highlighting to render correctly
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, {})
  end)
end

---@class InputDetails
---@field start_row integer
---@field start_col integer
---@field end_row integer
---@field name string
---@field value string

--- gets input mark at given row if there is one there
---@param context GrugFarContext
---@param buf integer
---@param row integer
---@return InputDetails?
function M.getInputAtRow(context, buf, row)
  local names = vim
    .iter(context.engine.inputs)
    :map(function(input)
      return input.name
    end)
    :totable()
  for i, input_name in ipairs(names) do
    local extmarkId = context.extmarkIds[input_name]
    local nextExtmarkId = context.extmarkIds[i < #names and names[i + 1] or 'results_header']

    if extmarkId and nextExtmarkId then
      local start_row, start_col =
        unpack(vim.api.nvim_buf_get_extmark_by_id(buf, context.namespace, extmarkId, {}))
      local end_boundary_row = unpack(
        vim.api.nvim_buf_get_extmark_by_id(
          buf,
          context.namespace,
          nextExtmarkId,
          { details = true }
        )
      )

      if start_row and end_boundary_row then
        ---@cast start_row integer
        ---@cast end_boundary_row integer
        local end_row = end_boundary_row - 1
        local value_lines = vim.api.nvim_buf_get_lines(buf, start_row, end_row + 1, false)
        local value = table.concat(value_lines, '\n')
        if row >= start_row and row <= end_row then
          return {
            name = input_name,
            value = value,
            start_row = start_row,
            start_col = start_col,
            end_row = end_row,
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
  local input = M.getInputAtRow(context, buf, cursor_row - 1)
  if not input then
    vim.api.nvim_feedkeys('p', 'n', false)
    return
  end

  local pasteCmd = 'p'
  if not is_visual then
    if input.end_row > input.start_row and cursor_row - 1 < input.end_row then
      -- we have a trailing line, nothing extra to do
      vim.api.nvim_feedkeys('p', 'n', false)
      return
    end

    if input.value == '' then
      pasteCmd = 'P'
    end
  end

  if pasteCmd == 'p' then
    -- add a blank line at bottom to force paste into the input
    fillInput(context, buf, input.name, input.value .. '\n', true)
    vim.api.nvim_win_set_cursor(win, { cursor_row, cursor_col })
  end

  M._pasteBelowCallback = function()
    input = M.getInputAtRow(context, buf, cursor_row - 1)
    if input and string.sub(input.value, -1) == '\n' then
      -- remove blank line
      vim.api.nvim_buf_set_lines(buf, input.end_row, input.end_row + 1, true, {})
    end
  end
  local keys = vim.api.nvim_replace_termcodes(
    pasteCmd .. '<esc><cmd>lua require("grug-far.inputs")._pasteBelowCallback()<cr>',
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

  local input = M.getInputAtRow(context, buf, cursor_row - 1)
  if not input then
    vim.api.nvim_feedkeys('P', 'n', false)
    return
  end

  local delete_newline = false

  if not is_visual then
    if input.end_row > input.start_row and cursor_row - 1 < input.end_row then
      -- we have a trailing line, nothing extra to do
      vim.api.nvim_feedkeys('P', 'n', false)
      return
    end

    if input.value == '' then
      delete_newline = true
    end
  end

  if is_visual then
    -- add a blank line at bottom to force paste into the input
    fillInput(context, buf, input.name, input.value .. '\n', true)
    vim.api.nvim_win_set_cursor(win, { cursor_row, cursor_col })
    delete_newline = true
  end

  M._pasteAboveCallback = function()
    input = M.getInputAtRow(context, buf, cursor_row - 1)
    if input and delete_newline and string.sub(input.value, -1) == '\n' then
      -- remove blank line
      vim.api.nvim_buf_set_lines(buf, input.end_row, input.end_row + 1, true, {})
    end
  end
  local keys = vim.api.nvim_replace_termcodes(
    'P<esc><cmd>lua require("grug-far.inputs")._pasteAboveCallback()<cr>',
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
  local input = M.getInputAtRow(context, buf, cursor_row - 1)
  if not input then
    vim.api.nvim_feedkeys('o', 'n', false)
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
