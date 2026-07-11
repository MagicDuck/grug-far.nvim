local M = {}

--- clears current match highlight
---@param context grug.far.Context
function M.clearCurrentMatchHighlight(context)
  if context.state.currentMatchBuf and vim.api.nvim_buf_is_valid(context.state.currentMatchBuf) then
    vim.api.nvim_buf_clear_namespace(context.state.currentMatchBuf, context.matchHlNamespace, 0, -1)
  end
  context.state.currentMatchBuf = nil
end

--- highlights current match in the source buffer
---@param context grug.far.Context
---@param location grug.far.ResultLocation
---@param targetBuf integer
function M.highlightCurrentMatch(context, location, targetBuf)
  M.clearCurrentMatchHighlight(context)

  if not location or not location.lnum or not location.col or not location.end_col then
    return
  end

  local start_row = location.start_lnum - 1
  local end_row = location.end_lnum - 1
  local ranges = location.submatches or { { col = location.col, end_col = location.end_col } }

  for _, range in ipairs(ranges) do
    local ok = pcall(
      vim.hl.range,
      targetBuf,
      context.matchHlNamespace,
      'GrugFarCurrentMatch',
      { start_row, range.col - 1 },
      { end_row, range.end_col - 1 }
    )

    if ok then
      context.state.currentMatchBuf = targetBuf
    end
  end
end

--- sets up autocommands for current match highlight
---@param buf integer
---@param context grug.far.Context
function M.setup(buf, context)
  -- re-apply highlight on entering grug buffer
  vim.api.nvim_create_autocmd({ 'BufEnter' }, {
    group = context.augroup,
    buffer = buf,
    callback = vim.schedule_wrap(function()
      if not vim.api.nvim_win_is_valid(vim.fn.bufwinid(buf)) then
        return
      end

      local resultsList = require('grug-far.render.resultsList')
      local location = resultsList.getResultLocationAtCursor(buf, context)
      if not location then
        return
      end

      local targetBuf = vim.fn.bufnr(location.filename)
      if targetBuf == -1 or not vim.api.nvim_buf_is_valid(targetBuf) then
        return
      end

      M.highlightCurrentMatch(context, location, targetBuf)
    end),
  })

  -- track cursor movement for live highlight
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = context.augroup,
    buffer = buf,
    callback = vim.schedule_wrap(function()
      if not vim.api.nvim_win_is_valid(vim.fn.bufwinid(buf)) then
        return
      end

      local resultsList = require('grug-far.render.resultsList')
      local location = resultsList.getResultLocationAtCursor(buf, context)

      if location == context.state.currentMatchLocation then
        return
      end

      context.state.currentMatchLocation = location

      if not location then
        M.clearCurrentMatchHighlight(context)
        return
      end

      local targetBuf = vim.fn.bufnr(location.filename)
      if targetBuf == -1 or not vim.api.nvim_buf_is_valid(targetBuf) then
        return
      end

      M.highlightCurrentMatch(context, location, targetBuf)
    end),
  })

  -- clear highlight on leaving grug buffer
  vim.api.nvim_create_autocmd({ 'BufLeave' }, {
    group = context.augroup,
    buffer = buf,
    callback = vim.schedule_wrap(function()
      M.clearCurrentMatchHighlight(context)
    end),
  })
end

return M
