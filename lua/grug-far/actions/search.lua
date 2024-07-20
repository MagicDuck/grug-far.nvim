local fetchResults = require('grug-far/rg/fetchResults')
local renderResultsHeader = require('grug-far/render/resultsHeader')
local resultsList = require('grug-far/render/resultsList')

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

  if state.abort.search then
    state.abort.search()
    state.abort.search = nil
  end

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
      if state.showRgCommand and effectiveArgs then
        resultsList.appendRgSearchCommand(buf, context, effectiveArgs)
      end
    end
  end

  state.abort.search, effectiveArgs = fetchResults({
    inputs = state.inputs,
    options = context.options,
    on_fetch_chunk = function(data)
      if state.bufClosed then
        return
      end

      clearResultsIfNeeded()

      state.status = 'progress'
      state.progressCount = state.progressCount + 1
      state.stats = {
        matches = state.stats.matches + data.stats.matches,
        files = state.stats.files + data.stats.files,
      }
      renderResultsHeader(buf, context)

      resultsList.appendResultsChunk(buf, context, data)
      resultsList.throttledForceRedrawBuffer(buf)
    end,
    on_finish = function(status, errorMessage)
      if state.bufClosed then
        return
      end

      state.abort.search = nil
      clearResultsIfNeeded()

      state.status = status
      if status == 'error' then
        state.stats = nil
        resultsList.setError(buf, context, errorMessage)
      else
        resultsList.highlight(buf, context)
      end

      renderResultsHeader(buf, context)
    end,
  })
end

return search
