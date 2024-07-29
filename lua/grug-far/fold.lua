local M = {}

M.getFoldLevel = function(lnum)
  local line = vim.fn.getline(lnum)
  if line and #line > 0 and (line:match('^(%d+:%d+:)') or line:match('^(%d+%-)')) then
    return 1
  end

  return 0
end

--- updates folds of first window associated with given buffer
---@param buf integer
M.updateFolds = function(buf)
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 then
    -- local cursor_row = unpack(vim.api.nvim_win_get_cursor(0))
    local cursor = vim.api.nvim_win_get_cursor(win)
    vim.fn.win_execute(win, 'normal zx')
    vim.api.nvim_win_set_cursor(win, cursor)

    -- if win == vim.api.nvim_get_current_win() then
    --   if vim.fn.mode():lower():find('i') ~= nil then
    --     local key = vim.api.nvim_replace_termcodes('<C-o>zx', true, false, true)
    --     vim.api.nvim_feedkeys(key, 'i', true)
    --   end
    -- else
    --   vim.fn.win_execute(win, 'normal zx')
    -- end

    -- vim.fn.win_execute(win, 'normal zx')
    -- if vim.fn.mode():lower():find('v') ~= nil then
    -- vim.fn.win_execute(win, 'startinsert!')
    -- end
  end
end

return M
