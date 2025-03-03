local resultsList = require('grug-far.render.resultsList')
local utils = require('grug-far.utils')

--- gets result location that we should open and row in buffer where it is referenced
---@param buf integer
---@param context GrugFarContext
---@param cursor_row integer
---@param increment -1 | 1 | nil
---@param count integer?
---@param includeUncounted boolean?
---@return ResultLocation?, integer?
local function getLocation(buf, context, cursor_row, increment, count, includeUncounted)
  if increment then
    local start_location = resultsList.getResultLocation(cursor_row - 1, buf, context)

    local num_lines = vim.api.nvim_buf_line_count(buf)
    for i = cursor_row + increment, increment > 0 and num_lines or 1, increment do
      local location = resultsList.getResultLocation(i - 1, buf, context)
      if
        location
        and location.lnum
        and (includeUncounted or location.count)
        and not (
          start_location
          and location.filename == start_location.filename
          and location.lnum == start_location.lnum
        )
      then
        return location, i
      end
    end
  else
    if count > 0 then
      for markId, location in pairs(context.state.resultLocationByExtmarkId) do
        if location.count == count then
          local row, _, details = unpack(
            vim.api.nvim_buf_get_extmark_by_id(
              buf,
              context.locationsNamespace,
              markId,
              { details = true }
            )
          )
          if details and not details.invalid then
            ---@cast row integer
            return location, row + 1
          end
        end
      end
    else
      return resultsList.getResultLocation(cursor_row - 1, buf, context), cursor_row
    end
  end
end

--- opens location at current cursor line (if there is one) in previous window
--- if count > 0 given, it will use the result location with that number instead
--- if increment is given, it will use the first location that is at least <increment> away from the current line
---@param params { buf: integer, context: GrugFarContext, increment: -1 | 1 | nil, count: number?, includeUncounted: boolean? }
local function openLocation(params)
  local buf = params.buf
  local context = params.context
  local increment = params.increment
  local includeUncounted = params.includeUncounted
  local count = params.count or 0
  local grugfar_win = vim.fn.bufwinid(buf)

  local cursor_row = unpack(vim.api.nvim_win_get_cursor(grugfar_win))
  local location, row = getLocation(buf, context, cursor_row, increment, count, includeUncounted)

  if not location then
    return
  end

  local targetWin = utils.getOpenTargetWin(context, buf)
  if row then
    vim.api.nvim_win_set_cursor(grugfar_win, { row, 0 })
  end

  vim.api.nvim_command([[execute "normal! m` "]])

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
