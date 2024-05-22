local fetchResults = require('grug-far/rg/fetchResults')
local renderResultsHeader = require('grug-far/render/resultsHeader')
local resultsList = require('grug-far/render/resultsList')

--- performs search
---@param params { buf: integer, context: GrugFarContext }
local function search(params)
  local buf = params.buf
  local context = params.context
  local state = context.state
  local isFinished = false

  if state.abortSearch then
    state.abortSearch()
    state.abortSearch = nil
  end

  -- initiate search in UI
  state.status = 'progress'
  state.progressCount = 0
  state.stats = { matches = 0, files = 0 }
  state.actionMessage = nil
  renderResultsHeader(buf, context)
  resultsList.clear(buf, context)

  state.abortSearch = fetchResults({
    inputs = state.inputs,
    options = context.options,
    on_fetch_chunk = vim.schedule_wrap(function(data)
      if isFinished then
        -- make sure to stop immediately when aborted early
        return
      end
      state.status = 'progress'
      state.progressCount = state.progressCount + 1
      state.stats = {
        matches = state.stats.matches + data.stats.matches,
        files = state.stats.files + data.stats.files,
      }
      renderResultsHeader(buf, context)

      resultsList.appendResultsChunk(buf, context, data)
    end),
    on_finish = vim.schedule_wrap(function(status, errorMessage)
      isFinished = true
      state.status = status
      if status == 'error' then
        state.stats = nil
        resultsList.setError(buf, context, errorMessage)
      elseif status == nil then
        -- was aborted
        state.stats = nil
        state.actionMessage = nil
      end

      renderResultsHeader(buf, context)
    end),
  })
end

return search
