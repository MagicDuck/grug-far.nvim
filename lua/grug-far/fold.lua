local engine = require('grug-far.engine')
local resultsList = require('grug-far.render.resultsList')
local inputs = require('grug-far.inputs')
local M = {}

--- updates folds of first window associated with given buffer
---@param buf integer
M.updateFolds = function(buf)
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 then
    -- Note: the following does not work when which-key is enabled for grug-far file type
    -- see https://github.com/folke/which-key.nvim/issues/830
    local cursor = vim.api.nvim_win_get_cursor(win)
    vim.fn.win_execute(win, 'normal! zx')
    vim.api.nvim_win_set_cursor(win, cursor)
  end
end

M._fold_funcs = {}
---@param context grug.far.Context
---@param win integer
---@param buf integer
function M.setup(context, win, buf)
  local folding = context.options.folding
  if folding.enabled then
    vim.wo[win][0].foldlevel = folding.foldlevel
    vim.wo[win][0].foldcolumn = folding.foldcolumn
    vim.wo[win][0].foldmethod = 'expr'

    M._fold_funcs[context.options.instanceName] = {
      foldexpr = function()
        -- ignore stuff in the inputs area
        if not vim.api.nvim_win_is_valid(win) then
          return
        end
        if vim.v.lnum <= inputs.getHeaderRow(context, buf) then
          return 0
        end

        local line = vim.fn.getline(vim.v.lnum)
        local loc = resultsList.getResultLocation(vim.v.lnum - 1, buf, context)
        if
          line == engine.DiffSeparatorChars or (loc and (folding.include_file_path or loc.lnum))
        then
          return 1
        end
        return 0
      end,
      foldtext = function()
        local loc = resultsList.getResultLocation(vim.v.foldstart - 1, buf, context)
        if loc and loc.filename and not loc.lnum then
          local res = ''
          if context.fileIconsProvider then
            local icon = context.fileIconsProvider:get_icon(loc.filename)
            res = res .. icon .. '  '
          end
          return res .. loc.filename
        end

        local linecount = vim.v.foldend - vim.v.foldstart + 1
        return linecount .. ' matching lines: ' .. vim.fn.getline(vim.v.foldstart)
      end,
    }

    vim.wo[win][0].foldexpr = 'v:lua.require("grug-far.fold")._fold_funcs["'
      .. context.options.instanceName
      .. '"].foldexpr()'
    vim.wo[win][0].foldtext = 'v:lua.require("grug-far.fold")._fold_funcs["'
      .. context.options.instanceName
      .. '"].foldtext()'
  else
    vim.wo[win][0].foldcolumn = '0'
  end
end

---@param context grug.far.Context
function M.cleanup(context)
  M._fold_funcs[context.options.instanceName] = nil
end

return M
