local resultsList = require('grug-far.render.resultsList')

local function previewLocation(params)
  local buf = params.buf
  local context = params.context
  local grugfar_win = vim.fn.bufwinid(buf)
  local cursor_row = unpack(vim.api.nvim_win_get_cursor(grugfar_win))
  local location = resultsList.getResultLocation(cursor_row - 1, buf, context)
  if location == nil then
    return
  end

  local width = vim.api.nvim_win_get_width(0)
  local height = vim.api.nvim_win_get_height(0)
  local opts = {
    relative = 'win',
    border = 'rounded',
    width = width,
    height = math.floor(height / 3),
    bufpos = { vim.fn.line('.') - 1, vim.fn.col('.') },
    focusable = true,
    win = grugfar_win,
    style = 'minimal',
  }

  local w = vim.api.nvim_open_win(0, true, opts)
  local bufnr = vim.fn.bufnr(location.filename)
  if bufnr == -1 then
    vim.fn.win_execute(w, 'e ' .. vim.fn.fnameescape(location.filename), true)
  else
    vim.api.nvim_win_set_buf(w, bufnr)
  end
  vim.api.nvim_win_set_cursor(w, { location.lnum, location.col - 1 })
  local b = vim.fn.winbufnr(w)
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = b })
end

return previewLocation
