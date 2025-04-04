local utils = require('grug-far.utils')
local resultsList = require('grug-far.render.resultsList')

--- opens location at current cursor line (if there is one) in target window
---@param params { buf: integer, context: GrugFarContext }
local function openLocation(params)
  local buf = params.buf
  local context = params.context

  local location = resultsList.getResultLocationAtCursor(buf, context)
  if not location then
    return
  end

  local targetWin = utils.getOpenTargetWin(context, buf)

  local targetBuf = vim.fn.bufnr(location.filename)
  if targetBuf == -1 then
    vim.fn.win_execute(
      targetWin,
      'keepjumps silent! e! ' .. utils.escape_path_for_cmd(location.filename),
      true
    )
    targetBuf = vim.api.nvim_win_get_buf(targetWin)
  else
    vim.api.nvim_win_set_buf(targetWin, targetBuf)
  end

  vim.api.nvim_set_option_value('buflisted', true, { buf = targetBuf })

  if not vim.b[targetBuf].__grug_far_was_visited then
    local bufHiddenAutocmdId, bufEnterAutocmdId
    bufHiddenAutocmdId = vim.api.nvim_create_autocmd({ 'BufHidden' }, {
      buffer = targetBuf,
      callback = function()
        vim.api.nvim_del_autocmd(bufHiddenAutocmdId)
        vim.api.nvim_del_autocmd(bufEnterAutocmdId)
        vim.api.nvim_set_option_value('buflisted', false, { buf = targetBuf })
        vim.schedule(function()
          -- note: using bdelete! instead of nvim_buf_delete or bwipeout!
          -- due to an issue in nvim similar to this issue described in oil:
          -- https://github.com/stevearc/oil.nvim/issues/435
          ---@diagnostic disable-next-line: param-type-mismatch
          pcall(vim.cmd, 'bdelete! ' .. targetBuf)
        end)
      end,
    })
    bufEnterAutocmdId = vim.api.nvim_create_autocmd({ 'WinEnter' }, {
      buffer = targetBuf,
      callback = function()
        vim.b[targetBuf].__grug_far_was_visited = true
        vim.api.nvim_del_autocmd(bufHiddenAutocmdId)
        vim.api.nvim_del_autocmd(bufEnterAutocmdId)
      end,
    })
  end

  pcall(
    vim.api.nvim_win_set_cursor,
    targetWin,
    { location.lnum or 1, location.col and location.col - 1 or 0 }
  )
end

return openLocation
