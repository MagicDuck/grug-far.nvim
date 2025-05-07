local treesitter = require('grug-far.render.treesitter')
local resultsList = require('grug-far.render.resultsList')
local M = {}

---@class grug.far.ReplacementInterpreter
---@field type grug.far.ReplacementInterpreterType
---@field language string
---@field get_eval_fn fun(script: string, arg_names: string[]): (fn: (fun(...): (result: string?, err: string?))?, error: string?)

--- returns engine given type
---@param type grug.far.ReplacementInterpreterType
---@return grug.far.ReplacementInterpreter?
function M.getReplacementInterpreter(type)
  if type == 'lua' then
    return require('grug-far.replacementInterpreter.luascript')
  elseif type == 'vimscript' then
    return require('grug-far.replacementInterpreter.vimscript')
  end

  return nil
end

--- sets replacement interpreter
---@param context grug.far.Context
---@param buf integer
---@param type grug.far.ReplacementInterpreterType
function M.setReplacementInterpreter(buf, context, type)
  local currentType = context.replacementInterpreter and context.replacementInterpreter.type
    or 'default'
  if currentType == type then
    return
  end

  -- clear results as it can be slow to clear syntax highlight otherwise
  resultsList.clear(buf, context)

  -- clear old syntax highlighting
  treesitter.clear(buf)

  local interpreter = M.getReplacementInterpreter(type)
  context.replacementInterpreter = interpreter
  context.state.normalModeSearch = interpreter and true or false
end

return M
