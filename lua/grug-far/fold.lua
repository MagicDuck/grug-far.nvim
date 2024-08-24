local engine = require('grug-far/engine')
local M = {}

---@param line string
---@return boolean
local function isPartOfFold(line)
  return line
    and #line > 0
    and (line == engine.DiffSeparatorChars or line:match('^(%d+:%d+:)') or line:match('^(%d+%-)'))
end

--- updates folds of first window associated with given buffer
---@param buf integer
M.updateFolds = function(buf)
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 then
    local currentWin = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_feedkeys(
      -- note: if in insert mode, <C-\><C-o> does a normal mode command without moving cursor
      -- see help ins-special-special
      vim.api.nvim_replace_termcodes('<C-\\><C-o><cmd>normal zx<cr>', true, false, true),
      'n',
      false
    )
    vim.api.nvim_set_current_win(currentWin)
  end
end

--- gets fold text
---@return string
M.getFoldText = function()
  local linecount = vim.v.foldend - vim.v.foldstart + 1
  return linecount .. ' matching lines: ' .. vim.fn.getline(vim.v.foldstart)
end

M._getFoldLevelFns = {}
---@param context GrugFarContext
---@param win integer
function M.setup(context, win)
  local folding = context.options.folding
  if folding.enabled then
    vim.api.nvim_set_option_value('foldlevel', folding.foldlevel, { win = win })
    vim.api.nvim_set_option_value('foldcolumn', folding.foldcolumn, { win = win })
    vim.api.nvim_set_option_value('foldmethod', 'expr', { win = win })

    M._getFoldLevelFns[context.options.instanceName] = function()
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

    vim.api.nvim_set_option_value(
      'foldexpr',
      'v:lua.require("grug-far/fold")._getFoldLevelFns["' .. context.options.instanceName .. '"]()',
      { win = win }
    )
    vim.api.nvim_set_option_value(
      'foldtext',
      'v:lua.require("grug-far/fold").getFoldText()',
      { win = win }
    )
  end
end

---@param context GrugFarContext
function M.cleanup(context)
  M._getFoldLevelFns[context.options.instanceName] = nil
end

return M
