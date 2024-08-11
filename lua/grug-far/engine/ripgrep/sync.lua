local syncChangedFiles = require('grug-far/engine/syncChangedFiles')
local getArgs = require('grug-far/engine/ripgrep/getArgs')
local utils = require('grug-far/utils')

local M = {}

--- are we doing a multiline search and replace?
---@param args string[]
---@return boolean
local function isMultilineSearchReplace(args)
  local multilineFlags = { '--multiline', '-U', '--multiline-dotall' }
  for _, arg in ipairs(args) do
    if utils.isBlacklistedFlag(arg, multilineFlags) then
      return true
    end
  end

  return false
end

--- does sync
---@param params EngineSyncParams
---@return fun()? abort
M.sync = function(params)
  local on_finish = params.on_finish

  local args = getArgs(params.inputs, params.options, {})
  if not args then
    on_finish(nil, nil, 'sync cannot work with the current arguments!')
    return
  end

  if isMultilineSearchReplace(args) then
    on_finish(nil, nil, 'sync disabled for multline search/replace!')
    return
  end

  return syncChangedFiles({
    options = params.options,
    report_progress = function(count)
      params.report_progress({ type = 'update_count', count = count })
    end,
    on_finish = params.on_finish,
    changedFiles = params.changedFiles,
  })
end

return M
