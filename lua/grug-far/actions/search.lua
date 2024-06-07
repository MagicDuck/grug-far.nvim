local fetchResults = require('grug-far/rg/fetchResults')
local renderResultsHeader = require('grug-far/render/resultsHeader')
local resultsList = require('grug-far/render/resultsList')

--- performs search
---@param params { buf: integer, context: GrugFarContext }
local function search(params)
  local buf = params.buf
  local context = params.context
  local state = context.state

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
  local function clearResultsIfNeeded()
    if not isCleared then
      isCleared = true
      resultsList.clear(buf, context)
    end
  end

  state.abort.search = fetchResults({
    inputs = state.inputs,
    options = context.options,
    -- TODO (sbadragan): unwrap other calls
    on_fetch_chunk = function(data)
      clearResultsIfNeeded()

      state.status = 'progress'
      state.progressCount = state.progressCount + 1
      state.stats = {
        matches = state.stats.matches + data.stats.matches,
        files = state.stats.files + data.stats.files,
      }
      renderResultsHeader(buf, context)

      resultsList.appendResultsChunk(buf, context, data)
      resultsList.forceRedrawBuffer(buf)
    end,
    on_finish = function(status, errorMessage)
      clearResultsIfNeeded()

      state.status = status
      if status == 'error' then
        state.stats = nil
        resultsList.setError(buf, context, errorMessage)
      end

      renderResultsHeader(buf, context)
    end,
  })
end

return search
