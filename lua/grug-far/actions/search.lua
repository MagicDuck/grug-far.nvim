local fetchResults = require('grug-far/rg/fetchResults')
local renderResultsHeader = require('grug-far/render/resultsHeader')
local resultsList = require('grug-far/render/resultsList')

local function search(params)
  local buf = params.buf
  local context = params.context
  local state = context.state

  if state.abortSearch then
    state.abortSearch();
    state.abortSearch = nil
  end

  vim.schedule(function()
    state.status = 'progress'
    state.progressCount = 0
    state.stats = { matches = 0, files = 0 }
    renderResultsHeader(buf, context)

    -- remove all lines after heading and add one blank line
    local headerRow = state.headerRow
    vim.api.nvim_buf_set_lines(buf, headerRow, -1, false, { "" })
  end)

  state.abortSearch = fetchResults({
    inputs = state.inputs,
    options = context.options,
    on_fetch_chunk = vim.schedule_wrap(function(data)
      state.status = 'progress'
      state.progressCount = state.progressCount + 1
      state.stats = {
        matches = state.stats.matches + data.stats.matches,
        files = state.stats.files + data.stats.files
      }
      renderResultsHeader(buf, context)

      resultsList.appendResultsChunk(buf, context, data)
    end),
    on_finish = vim.schedule_wrap(function(status, errorMessage)
      state.abortSearch = nil

      state.status = status
      state.progressCount = nil
      if status == 'error' then
        state.stats = nil
        resultsList.appendError(buf, context, errorMessage)
      end

      renderResultsHeader(buf, context)
    end),
  })
end

return search
