local render = require("grug-far/render")
local replace = require("grug-far/actions/replace")

local M = {}

local function setBufKeymap(buf, modes, desc, lhs, callback)
  for i = 1, #modes do
    local mode = modes:sub(i, i)
    vim.api.nvim_buf_set_keymap(buf, mode, lhs, '',
      { noremap = true, desc = desc, callback = callback })
  end
end

local function setupKeymap(buf, context)
  local keymaps = context.options.keymaps
  if keymaps.replace then
    setBufKeymap(buf, 'niv', 'Grug Far: apply replacements', keymaps.replace, function()
      replace({ buf = buf, context = context })
    end)
  end
end

local function setupRenderer(win, buf, context)
  local function onBufferChange(params)
    render({ buf = params.buf }, context)

    if context.state.isFirstRender then
      context.state.isFirstRender = false
      vim.api.nvim_win_set_cursor(win, { 2, 0 })
    end
  end

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = buf,
    callback = onBufferChange
  })
end

function M.createBuffer(win, context)
  local buf = vim.api.nvim_create_buf(true, true)
  setupKeymap(buf, context)
  setupRenderer(win, buf, context)

  vim.api.nvim_win_set_buf(win, buf)
  vim.cmd('startinsert!')

  return buf
end

return M
