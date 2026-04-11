local syncChangedFiles = require('grug-far.engine.syncChangedFiles')
local getArgs = require('grug-far.engine.ripgrep.getArgs')
local utils = require('grug-far.utils')
local syncBufrange = require('grug-far.engine.syncBufrange')
local async_job = require('grug-far.async_job')

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
---@param params grug.far.EngineSyncParams
---@return fun()? abort
M.sync = function(params)
  local on_finish = params.on_finish

  local args = getArgs(params.inputs, params.options, {})
  if not args then
    on_finish(nil, nil, 'sync cannot work with the current arguments!')
    return
  end

  if isMultilineSearchReplace(args) then
    on_finish(nil, nil, 'sync disabled for multiline search/replace!')
    return
  end

  local bufrange, bufrange_err = utils.getBufrange(params.inputs.paths)
  if bufrange_err then
    params.on_finish('error', bufrange_err)
    return
  end

  local hooks = params.options.hooks

  return async_job.chain(function(finish)
    if not hooks.on_before_edit_file then
      finish('success')
      return
    end

    params.report_progress({ type = 'message', message = 'running on before edit file hook' })

    return async_job.parallel_process({
      items = vim
        .iter(params.changedFiles)
        :map(function(changedFile)
          return { path = changedFile.filename, isBufferRange = not not bufrange }
        end)
        :totable(),
      maxWorkers = params.options.maxWorkers,
      process_item = hooks.on_before_edit_file,
      on_finish = finish,
    })
  end, function(finish)
    params.report_progress({ type = 'update_count', count = 0 })
    if bufrange then
      return syncBufrange({
        changes = params.changedFiles[1],
        bufrange = bufrange,
        on_done = function(err)
          if err then
            finish('error', err)
          else
            params.report_progress({ type = 'update_count', count = 1 })
            finish('success')
          end
        end,
      })
    else
      return syncChangedFiles({
        options = params.options,
        report_progress = function(count)
          params.report_progress({ type = 'update_count', count = count })
        end,
        on_finish = finish,
        changedFiles = params.changedFiles,
      })
    end
  end)(params.on_finish)
end

return M
