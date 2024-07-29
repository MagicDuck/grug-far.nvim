local M = {}

---@param line string
---@return boolean
local function isPartOfFold(line)
  return line and #line > 0 and (line:match('^(%d+:%d+:)') or line:match('^(%d+%-)'))
end

--- gets fold level of line at given number
---@param lnum integer
---@return integer
M.getFoldLevel = function(lnum)
  local line = vim.fn.getline(lnum)
  -- TODO (sbadragan): need this?
  -- local nextline = vim.fn.getline(lnum + 1)

  -- if isPartOfFold(line) or isPartOfFold(nextline) then
  if isPartOfFold(line) then
    return 1
  end
  return 0
end

--- updates folds of first window associated with given buffer
---@param buf integer
M.updateFolds = function(buf)
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 then
    local cursor = vim.api.nvim_win_get_cursor(win)
    vim.fn.win_execute(win, 'normal zx')
    vim.api.nvim_win_set_cursor(win, cursor)
  end
end

return M
