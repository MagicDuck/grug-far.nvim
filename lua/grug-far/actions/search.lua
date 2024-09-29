local renderResultsHeader = require('grug-far.render.resultsHeader')
local resultsList = require('grug-far.render.resultsList')
local fold = require('grug-far.fold')

--- performs search
---@param params { buf: integer, context: GrugFarContext }
local function search(params)
  local buf = params.buf
  local context = params.context
  local state = context.state
  local abort = state.abort

  if abort.sync then
    vim.notify('grug-far: sync in progress', vim.log.levels.INFO)
    return
  end

  if abort.replace then
    vim.notify('grug-far: replace in progress', vim.log.levels.INFO)
    return
  end

  if abort.search then
    if not state.searchAgain then
      state.searchAgain = true
      abort.search()
    end
    return
  end

  local abortedEarly = false

  -- initiate search in UI
  state.status = 'progress'
  state.progressCount = 0
  state.stats = { matches = 0, files = 0 }
  state.actionMessage = nil

  -- note: we clear first time we fetch more info instead of intially
  -- in order to reduce flicker
  local isCleared = false
  local effectiveArgs
  local function clearResultsIfNeeded()
    if not isCleared then
      isCleared = true
      resultsList.clear(buf, context)
      if state.showSearchCommand and effectiveArgs then
        resultsList.appendSearchCommand(buf, context, effectiveArgs)
      end
    end
  end

  local on_finish = function(status, errorMessage, customActionMessage)
    if state.bufClosed then
      return
    end

    if abortedEarly and status == nil then
      status = 'success'
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

    state.abort.search = nil
    -- launch a new search if one was triggered while we were finishing up  or were aborted
    if state.searchAgain then
      state.searchAgain = false
      search(params)
    end
  end

  abort.search, effectiveArgs = context.engine.search({
    inputs = state.inputs,
    options = context.options,
    replacementInterpreter = context.replacementInterpreter,
    on_fetch_chunk = function(data)
      if state.bufClosed or abortedEarly then
        return
      end

      clearResultsIfNeeded()

      state.status = 'progress'
      state.progressCount = state.progressCount + 1
      state.stats.matches = state.stats.matches + data.stats.matches
      state.stats.files = state.stats.files + data.stats.files

      abortedEarly = context.options.maxSearchMatches ~= nil
        and state.stats.matches > context.options.maxSearchMatches

      if abortedEarly then
        state.actionMessage = 'exceeded '
          .. context.options.maxSearchMatches
          .. ' matches, aborting early!'
      end
      renderResultsHeader(buf, context)

      resultsList.appendResultsChunk(buf, context, data)
      resultsList.throttledForceRedrawBuffer(buf, context)

      if abortedEarly then
        if state.abort.search then
          state.abort.search()
          vim.schedule(function()
            on_finish('success', nil, nil)
          end)
        end
      end
    end,
    on_finish = on_finish,
  })
end

return search
