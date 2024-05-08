local resultsList = require('grug-far/render/resultsList')
-- TODO (sbadragan): plan
-- 1. create a new namespace, locationsNamespace
-- 2. clear it in the clear function
-- 3. add marks to the buffer and build a map resultLocationByExmarkId markId => {file, row, col}
-- 4. on enter, get cursor row, get extmark at row
-- 5. reference resultLocationByExmarkId[extmarkId], open file in side buffer, navigate to row, col

local function gotoLocation(params)
  local buf = params.buf
  local context = params.context

  local cursor_row = vim.api.nvim_win_get_cursor(buf) - 1
  local location = resultsList.getClosestResultLocation(cursor_row, buf, context)
  if not location then
    return
  end

  if context.prevWin ~= nil then
    vim.fn.win_gotoid(context.prevWin)
  end
  vim.api.nvim_command([[execute "normal! m` "]])
  vim.cmd('e ' .. vim.fn.fnameescape(location.filename))
  vim.api.nvim_win_set_cursor(0, { location.lnum or 1, location.col and location.col - 1 or 0 })
end

return gotoLocation

-- state.target_winid = api.nvim_get_current_win() before the FAR buffer is created
-- M.select_entry = function()
--   local t = M.get_current_entry()
--   if t == nil then
--     return nil
--   end
--   if config.is_open_target_win and state.target_winid ~= nil then
--     open_file(t.filename, t.lnum, t.col, state.target_winid)
--   else
--     open_file(t.filename, t.lnum, t.col)
--   end
-- end
--
-- local open_file = function(filename, lnum, col, winid)
--   if winid ~= nil then
--     vim.fn.win_gotoid(winid)
--   end
--   vim.api.nvim_command([[execute "normal! m` "]])
--   local escaped_filename = vim.fn.fnameescape(filename)
--   vim.cmd('e ' .. escaped_filename)
--   api.nvim_win_set_cursor(0, { lnum, col })
-- end


-- https://github.com/kevinhwang91/nvim-bqf/blob/7751b6ef9fbc3907478eaf23e866c4316a2ed1b4/lua/bqf/qfwin/handler.lua#L233
---@param close boolean
---@param jumpCmd boolean
---@param qwinid number
---@param idx number
-- function open(close, jumpCmd, qwinid, idx)
--   doEdit(qwinid, idx, close, function(bufnr)
--     if jumpCmd then
--       local fname = fn.fnameescape(api.nvim_buf_get_name(bufnr))
--       if jumpCmd == 'drop' then
--         local bufInfo = fn.getbufinfo(bufnr)
--         if fname == '' or #bufInfo == 1 and #bufInfo[1].windows == 0 then
--           api.nvim_set_current_buf(bufnr)
--           return
--         end
--       end
--       cmd(('%s %s'):format(jumpCmd, fname))
--     else
--       api.nvim_set_current_buf(bufnr)
--     end
--   end)
-- end
--
-- local function doEdit(qwinid, idx, close, action)
--   qwinid = qwinid or api.nvim_get_current_win()
--   local qs = qfs:get(qwinid)
--   local pwinid = qs:previousWinid()
--   local qlist = qs:list()
--   local size = qlist:getQfList({ size = 0 }).size
--   if size <= 0 then
--     api.nvim_err_writeln('E42: No Errors')
--     return false
--   end
--   if not utils.isWinValid(pwinid) then
--     vim.notify('file window is invalid', vim.log.levels.WARN)
--     cmd([[exe "norm! \<CR>"]])
--     api.nvim_win_set_height(qwinid, math.min(10, size))
--     return false
--   end
--
--   idx = idx or api.nvim_win_get_cursor(qwinid)[1]
--   qlist:changeIdx(idx)
--   local entry = qlist:item(idx)
--   local bufnr, lnum, col = entry.bufnr, entry.lnum, entry.col
--   if bufnr == 0 then
--     api.nvim_err_writeln('Buffer not found')
--     return
--   end
--
--   if close then
--     api.nvim_win_close(qwinid, true)
--   end
--
--   api.nvim_set_current_win(pwinid)
--
--   local lastBufnr = api.nvim_get_current_buf()
--   local lastBufname = api.nvim_buf_get_name(lastBufnr)
--   local lastBufoff = api.nvim_buf_get_offset(0, 1)
--   if action and not utils.isUnNameBuf(lastBufnr, lastBufname, lastBufoff) then
--     action(bufnr)
--   else
--     api.nvim_set_current_buf(bufnr)
--   end
--
--   vim.bo.buflisted = true
--   pcall(api.nvim_win_set_cursor, 0, { lnum, math.max(0, col - 1) })
--
--   if vim.wo.foldenable and vim.o.fdo:match('quickfix') then
--     cmd('norm! zv')
--   end
--   utils.zz()
--
--   if utils.isUnNameBuf(lastBufnr, lastBufname, lastBufoff) then
--     api.nvim_buf_delete(lastBufnr, {})
--   end
--   return true
-- end
