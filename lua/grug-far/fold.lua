local engine = require('grug-far/engine')
local M = {}

---@param line string
---@return boolean
local function isPartOfFold(line)
  -- TODO (sbadragan): should only check stuff that is below the results line
  return line
    and #line > 0
    and (line == engine.DiffSeparatorChars or line:match('^(%d+:%d+:)') or line:match('^(%d+%-)'))
end

--- constructs getter that gets fold level of line at given number
---@param GrugFarContext
M.getFoldLevelGetter = function(context)
  return function()
    -- ignore stuff in the inputs area
    if vim.v.lnum <= context.state.headerRow then
      return 0
    end

    local line = vim.fn.getline(vim.v.lnum)
    if isPartOfFold(line) then
      return 1
    end
    return 0
  end
end
M.getFoldLevelFns = {}

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

--- gets fold text
---@return string
M.getFoldText = function()
  local linecount = vim.v.foldend - vim.v.foldstart + 1
  return linecount .. ' matching lines: ' .. vim.fn.getline(vim.v.foldstart)
end

return M
