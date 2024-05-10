local render = require("grug-far/render")
local replace = require("grug-far/actions/replace")
local qflist = require("grug-far/actions/qflist")
local gotoLocation = require("grug-far/actions/gotoLocation")
local close = require("grug-far/actions/close")

local M = {}

local function setBufKeymap(buf, modes, desc, lhs, callback)
  for i = 1, #modes do
    local mode = modes:sub(i, i)
    vim.api.nvim_buf_set_keymap(buf, mode, lhs, '',
      { noremap = true, desc = desc, callback = callback, nowait = true })
  end
end

local function setupKeymap(win, buf, context)
  local keymaps = context.options.keymaps
  if #keymaps.replace > 0 then
    setBufKeymap(buf, 'ni', 'Grug Far: apply replacements', keymaps.replace, function()
      replace({ buf = buf, context = context })
    end)
  end
  if #keymaps.qflist > 0 then
    setBufKeymap(buf, 'ni', 'Grug Far: send results to quickfix list', keymaps.qflist, function()
      qflist({ context = context })
    end)
  end
  if #keymaps.gotoLocation > 0 then
    setBufKeymap(buf, 'n', 'Grug Far: go to location', keymaps.gotoLocation, function()
      gotoLocation({ win = win, buf = buf, context = context })
    end)
  end
  if #keymaps.close > 0 then
    setBufKeymap(buf, 'niv', 'Grug Far: close', keymaps.close, function()
      close()
    end)
  end
end

local function setupRenderer(buf, context)
  local function onBufferChange(params)
    render({ buf = params.buf }, context)
  end

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = buf,
    callback = onBufferChange
  })
end

function M.createBuffer(win, context)
  local buf = vim.api.nvim_create_buf(true, true)
  setupKeymap(win, buf, context)
  setupRenderer(buf, context)
  vim.schedule(function()
    render({ buf = buf }, context)
    vim.api.nvim_win_set_cursor(win, { 3, 0 })
  end)

  vim.api.nvim_win_set_buf(win, buf)
  vim.cmd('startinsert!')

  return buf
end

return M
