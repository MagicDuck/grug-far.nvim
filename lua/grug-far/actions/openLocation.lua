local utils = require('grug-far.utils')
local resultsList = require('grug-far.render.resultsList')

--- opens location at current cursor line (if there is one) in target window
---@param params { buf: integer, context: grug.far.Context, useScratchBuffer?: boolean }
local function openLocation(params)
  local buf = params.buf
  local context = params.context
  local useScratchBuffer = params.useScratchBuffer

  local location = resultsList.getResultLocationAtCursor(buf, context)
  if not location then
    return
  end

  local targetWin = utils.getOpenTargetWin(context, buf)

  local targetBuf = vim.fn.bufnr(location.filename)
  if targetBuf == -1 then
    targetBuf = vim.api.nvim_create_buf(true, false)
    -- load lines into target buf and highlight them manually (to prevent LSP kickoff)
    vim.api.nvim_buf_set_name(targetBuf, location.filename)

    if useScratchBuffer then
      vim.bo[targetBuf].buftype = 'nofile'
      vim.b[targetBuf].__grug_far_scratch_buf = true
      local lines = utils.readFileLinesSync(location.filename)
      if lines then
        vim.api.nvim_buf_set_lines(targetBuf, 0, -1, false, lines)
        local ft = utils.getFileType(location.filename)
        if ft then
          local lang = vim.treesitter.language.get_lang(ft)
          if not pcall(vim.treesitter.start, targetBuf, lang) then
            vim.bo[buf].syntax = ft
          end
        end
      end
    else
      vim.api.nvim_buf_call(targetBuf, function()
        vim.cmd('keepjumps silent! edit!')
      end)
    end

    local bufHiddenAutocmdId, bufEnterAutocmdId
    bufHiddenAutocmdId = vim.api.nvim_create_autocmd({ 'BufHidden' }, {
      buffer = targetBuf,
      callback = function()
        vim.api.nvim_del_autocmd(bufHiddenAutocmdId)
        vim.api.nvim_del_autocmd(bufEnterAutocmdId)
        vim.api.nvim_set_option_value('buflisted', false, { buf = targetBuf })
        vim.b[targetBuf].__grug_far_scratch_buf = nil
        vim.schedule(function()
          -- note: using bdelete! instead of nvim_buf_delete or bwipeout!
          -- due to an issue in nvim similar to this issue described in oil:
          -- https://github.com/stevearc/oil.nvim/issues/435
          ---@diagnostic disable-next-line: param-type-mismatch
          pcall(vim.cmd, 'bwipeout! ' .. targetBuf)
        end)
      end,
    })
    bufEnterAutocmdId = vim.api.nvim_create_autocmd({ 'WinEnter' }, {
      buffer = targetBuf,
      callback = function()
        vim.api.nvim_del_autocmd(bufHiddenAutocmdId)
        vim.api.nvim_del_autocmd(bufEnterAutocmdId)

        if useScratchBuffer then
          vim.schedule(function()
            utils.convertScratchBufToRealBuf(targetBuf)
          end)
        end
      end,
    })
  end

  vim.api.nvim_win_set_buf(targetWin, targetBuf)
  pcall(
    vim.api.nvim_win_set_cursor,
    targetWin,
    { location.lnum or 1, location.col and location.col - 1 or 0 }
  )
end

return openLocation
