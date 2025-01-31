local renderResultsHeader = require('grug-far.render.resultsHeader')
local resultsList = require('grug-far.render.resultsList')
local fold = require('grug-far.fold')
local tasks = require('grug-far.tasks')
local utils = require('grug-far.utils')

---@enum SearchUpdateType
local SearchUpdateType = {
  FetchChunk = 1,
  Finish = 2,
}

--- performs search
---@param params { buf: integer, context: GrugFarContext }
local function search(params)
  local buf = params.buf
  local context = params.context
  local state = context.state

  if tasks.hasActiveTasksWithType(context, 'sync') then
    vim.notify('grug-far: sync in progress', vim.log.levels.INFO)
    return
  end

  if tasks.hasActiveTasksWithType(context, 'replace') then
    vim.notify('grug-far: replace in progress', vim.log.levels.INFO)
    return
  end

  -- abort all previous searches
  vim.iter(tasks.getTasksByType(context, 'search')):each(function(t)
    tasks.abortTask(context, t)
  end)

  local task = tasks.createTask(context, 'search')
  local abort
  local effectiveArgs

  -- TODO (sbadragan): remove
  local count = 0
  local startTime = vim.uv.now()

  -- initiate search in UI
  state.status = 'progress'
  state.progressCount = 0
  state.stats = { matches = 0, files = 0 }
  state.actionMessage = nil

  local isCleared = false
  local function clearResultsIfNeeded()
    if not isCleared then
      isCleared = true
      resultsList.clear(buf, context)
      if state.showSearchCommand and effectiveArgs then
        resultsList.appendSearchCommand(buf, context, effectiveArgs)
      end
    end
  end

  -- note: we clear first time we fetch more info or after 100ms instead of initially
  -- in order to reduce flicker
  utils.setTimeout(
    tasks.task_callback_wrap(context, task, vim.schedule_wrap(clearResultsIfNeeded)),
    100
  )

  local on_finish = function(status, errorMessage, customActionMessage)
    if context.state.bufClosed then
      return
    end

    if customActionMessage then
      state.actionMessage = customActionMessage
    end

    state.status = status
    if status == 'error' then
      state.stats = nil
      resultsList.setError(buf, context, errorMessage)
      if state.showSearchCommand and effectiveArgs then
        resultsList.appendSearchCommand(buf, context, effectiveArgs)
      end
    else
      if errorMessage and #errorMessage > 0 then
        resultsList.appendWarning(buf, context, errorMessage)

        local lastline = vim.api.nvim_buf_line_count(buf)
        local winheight = vim.api.nvim_win_get_height(vim.fn.bufwinid(buf))
        state.actionMessage = lastline < winheight and ' warnings!'
          or ' warnings, see end of buffer!'
      end
      resultsList.highlight(buf, context)
    end

    if context.options.folding.enabled then
      fold.updateFolds(buf)
    end

    tasks.finishTask(context, task)
  end

  -- set up update queue
  local update_queue = {}
  local MAX_PROCESSING_BLOCK_SIZE = 1
  local perform_update = function(data)
    clearResultsIfNeeded()

    if data.type == SearchUpdateType.Finish then
      local time = vim.uv.now() - startTime
      print('did', count, 'in', time, 'rate duration is', time / count)

      on_finish(vim.F.unpack_len(data.params))
    else -- FetchChunk
      count = count + 1

      state.status = 'progress'
      state.progressCount = state.progressCount + 1
      state.stats.matches = state.stats.matches + data.stats.matches
      state.stats.files = state.stats.files + data.stats.files

      -- resultsList.appendResultsChunk(buf, context, data)
    end
  end

  local update_timer = vim.uv.new_timer()
  local UPDATE_INTERVAL = 40
  update_timer:start(
    0,
    UPDATE_INTERVAL,
    vim.schedule_wrap(function()
      local isDone = state.bufClosed or (task.isFinished and task.abortReason ~= 'abortedEarly')
      if isDone then
        if not update_timer:is_closing() then
          update_timer:stop()
          update_timer:close()
        end
        return
      end

      if #update_queue == 0 then
        return
      end

      for _ = 1, math.min(MAX_PROCESSING_BLOCK_SIZE, #update_queue), 1 do
        local chunk = table.remove(update_queue, 1)
        perform_update(chunk)
      end
      renderResultsHeader(buf, context)
      resultsList.forceRedrawBuffer(buf, context)
      resultsList.throttledHighlight(buf, context)
    end)
  )

  local fetched_matches = 0
  abort, effectiveArgs = context.engine.search({
    inputs = state.inputs,
    options = context.options,
    replacementInterpreter = context.replacementInterpreter,
    on_fetch_chunk = tasks.task_callback_wrap(context, task, function(data)
      fetched_matches = fetched_matches + data.stats.matches
      local abortEarly = context.options.maxSearchMatches ~= nil
        and fetched_matches > context.options.maxSearchMatches

      data.type = SearchUpdateType.FetchChunk
      table.insert(update_queue, data)

      if abortEarly then
        tasks.abortTask(context, task, 'abortedEarly')
        table.insert(update_queue, {
          params = {
            'success',
            nil,
            'exceeded ' .. context.options.maxSearchMatches .. ' matches, aborting early!',
          },
          type = SearchUpdateType.Finish,
        })
      end
    end),
    on_finish = tasks.task_callback_wrap(context, task, function(...)
      local paramz = vim.F.pack_len(...)
      table.insert(update_queue, {
        params = paramz,
        type = SearchUpdateType.Finish,
      })
    end),
  })

  task.abort = abort
end

return search
