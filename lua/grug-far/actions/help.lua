local utils = require('grug-far/utils')
local opts = require('grug-far/opts')

--- appends header text to help buffer
---@param helpBuf integer
---@param context GrugFarContext
---@param text string
---@param line integer
local function appendHeader(helpBuf, context, text, line)
  vim.api.nvim_buf_set_lines(helpBuf, line, line + 1, true, { text })
  vim.api.nvim_buf_add_highlight(helpBuf, context.helpHlNamespace, 'GrugFarInputLabel', line, 1, -1)
end

--- renders contents of history buffer
---@param helpBuf integer
---@param context GrugFarContext
local function renderHelpBuffer(helpBuf, context)
  appendHeader(helpBuf, context, 'Keyboard Shortcuts:', 0)
end

--- creates help window
---@param buf integer
---@param context GrugFarContext
local function createHelpWindow(buf, context)
  local helpBuf = vim.api.nvim_create_buf(false, true)
  local width = vim.api.nvim_win_get_width(0) - 2
  local height = math.floor(vim.api.nvim_win_get_height(0) / 2)
  local historyWin = vim.api.nvim_open_win(helpBuf, true, {
    relative = 'win',
    row = 0,
    col = 2,
    width = width,
    height = height,
    border = 'rounded',
    footer = (opts.getIcon('historyTitle', context) or ' ') .. 'Help ',
    footer_pos = 'center',
    style = 'minimal',
  })

  -- delete buffer on window close
  vim.api.nvim_create_autocmd({ 'WinClosed' }, {
    group = context.augroup,
    buffer = helpBuf,
    callback = function()
      vim.api.nvim_buf_delete(helpBuf, { force = true })
    end,
  })

  vim.api.nvim_set_option_value('filetype', 'grug-far-help', { buf = helpBuf })
  renderHelpBuffer(helpBuf, context)

  return historyWin
end

--- shows help
---@param params { buf: integer, context: GrugFarContext }
local function help(params)
  local context = params.context
  local buf = params.buf

  createHelpWindow(buf, context)
end

return help
