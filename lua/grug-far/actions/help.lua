local utils = require('grug-far.utils')
local opts = require('grug-far.opts')

---@alias HlText string[]

--- adds given highlighted lines to help buffer
---@param helpBuf integer
---@paratem context grug.far.Context
---@param lines HlText[][]
---@param indent integer
local function add_highlighted_lines(helpBuf, context, lines, indent)
  for i, line in ipairs(lines) do
    local lineText = string.rep(' ', indent)
    for _, hlText in ipairs(line) do
      lineText = lineText .. hlText[1]
    end
    vim.api.nvim_buf_set_lines(helpBuf, i - 1, i, false, { lineText })

    local pos = indent
    for _, hlText in ipairs(line) do
      local hlGroup = hlText[2]
      local textLen = #hlText[1]
      if hlGroup and textLen > 0 then
        vim.hl.range(
          helpBuf,
          context.helpHlNamespace,
          hlGroup,
          { i - 1, pos },
          { i - 1, pos + textLen }
        )
      end
      pos = pos + textLen
    end
  end
end

--- renders contents of history buffer
---@param helpBuf integer
---@param context grug.far.Context
local function renderHelpBuffer(helpBuf, context)
  local lines = {
    { { 'Actions:', 'GrugFarHelpWinHeader' } },
  }
  local maxActionItemLen = 0
  for _, action in ipairs(context.actions) do
    local shortcut = utils.getActionMapping(action.keymap) or '(unbound)'
    local itemLen = #action.text + #shortcut
    if maxActionItemLen < itemLen then
      maxActionItemLen = itemLen
    end
  end
  for _, action in ipairs(context.actions) do
    local shortcut = utils.getActionMapping(action.keymap) or '(unbound)'
    table.insert(lines, {
      { ' - ', 'GrugFarHelpWinActionPrefix' },
      {
        action.text,
        'GrugFarHelpWinActionText',
      },
      { ' ' },
      { shortcut, 'GrugFarHelpWinActionKey' },
      { string.rep(' ', maxActionItemLen - #action.text - #shortcut + 3) },
      { action.description, 'GrugFarHelpWinActionDescription' },
    })
  end
  add_highlighted_lines(helpBuf, context, lines, 2)
end

--- creates help window
---@param context grug.far.Context
local function createHelpWindow(context)
  local helpBuf = vim.api.nvim_create_buf(false, true)
  local width = vim.api.nvim_win_get_width(0) - 2
  local height = math.floor(vim.api.nvim_win_get_height(0) / 2)
  local helpWinConfig = vim.tbl_extend('force', {
    relative = 'win',
    row = 0,
    col = 2,
    width = width,
    height = height,
    footer = (opts.getIcon('helpTitle', context) or ' ') .. 'Help (press <q> or <esc> to close)',
    footer_pos = 'center',
    border = 'rounded',
    style = 'minimal',
  }, context.options.helpWindow)
  local helpWin = vim.api.nvim_open_win(helpBuf, true, helpWinConfig)
  vim.api.nvim_set_option_value('wrap', true, { win = helpWin })

  -- delete buffer on window close
  vim.api.nvim_create_autocmd({ 'WinClosed' }, {
    group = context.augroup,
    buffer = helpBuf,
    callback = function()
      vim.api.nvim_buf_delete(helpBuf, { force = true })
    end,
  })

  -- close on <ESC> and q
  vim.api.nvim_buf_set_keymap(
    helpBuf,
    'n',
    '<ESC>',
    ':q<CR>',
    { noremap = true, nowait = true, silent = true }
  )
  vim.api.nvim_buf_set_keymap(
    helpBuf,
    'n',
    'q',
    ':q<CR>',
    { noremap = true, nowait = true, silent = true }
  )

  vim.api.nvim_set_option_value('filetype', 'grug-far-help', { buf = helpBuf })
  renderHelpBuffer(helpBuf, context)
  vim.api.nvim_set_option_value('modifiable', false, { buf = helpBuf })

  return helpWin
end

--- shows help
---@param params { buf: integer, context: grug.far.Context }
local function help(params)
  local context = params.context

  createHelpWindow(context)
end

return help
