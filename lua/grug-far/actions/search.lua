local renderResultsHeader = require('grug-far.render.resultsHeader')
local resultsList = require('grug-far.render.resultsList')
local fold = require('grug-far.fold')
local tasks = require('grug-far.tasks')
local utils = require('grug-far.utils')

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

  if tasks.hasActiveTasksWithType(context, 'search') then
    -- abort all previous searches
    vim.iter(tasks.getActiveTasksByType(context, 'search')):each(function(t)
      tasks.abortTask(context, t)
    end)
  end

  local task = tasks.createTask(context, 'search')
  local abort
  local effectiveArgs

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

    clearResultsIfNeeded()

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

    renderResultsHeader(buf, context)

    if context.options.folding.enabled then
      fold.updateFolds(buf)
    end

    tasks.finishTask(context, task)
  end

  abort, effectiveArgs = context.engine.search({
    inputs = state.inputs,
    options = context.options,
    replacementInterpreter = context.replacementInterpreter,
    on_fetch_chunk = tasks.task_callback_wrap(context, task, function(data)
      clearResultsIfNeeded()

      state.status = 'progress'
      state.progressCount = state.progressCount + 1
      state.stats.matches = state.stats.matches + data.stats.matches
      state.stats.files = state.stats.files + data.stats.files

      local abortEarly = context.options.maxSearchMatches ~= nil
        and state.stats.matches > context.options.maxSearchMatches

      if abortEarly then
        state.actionMessage = 'exceeded '
          .. context.options.maxSearchMatches
          .. ' matches, aborting early!'
      end
      renderResultsHeader(buf, context)

      resultsList.appendResultsChunk(buf, context, data)
      resultsList.throttledForceRedrawBuffer(buf, context)

      if abortEarly then
        tasks.abortTask(context, task)
        on_finish('success', nil, nil)
      end
    end),
    on_finish = tasks.task_callback_wrap(context, task, on_finish),
  })

  task.abort = abort
end

return search
