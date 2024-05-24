local utils = require('grug-far/utils')
local renderResultsHeader = require('grug-far/render/resultsHeader')
local resultsList = require('grug-far/render/resultsList')

--- opens quickfix list
---@param context GrugFarContext
---@param resultsLocations ResultLocation[]
local function openQuickfixList(context, resultsLocations)
  local search = context.state.inputs.search
  vim.fn.setqflist(resultsLocations, 'r')
  vim.fn.setqflist({}, 'a', {
    title = 'Grug FAR results'
      .. utils.strEllideAfter(search, context.options.maxSearchCharsInTitles, ' for: '),
  })
  -- open list below taking whole horizontal space
  vim.cmd('botright copen | stopinsert')
end

--- gets the result locations for the quickfix list, ignoring ones for deleted
--- lines in results are and such
---@param buf integer
---@param context GrugFarContext
---@return ResultLocation[]
local function getResultsLocations(buf, context)
  local all_extmarks = vim.api.nvim_buf_get_extmarks(
    0,
    context.locationsNamespace,
    { 0, 0 },
    { -1, -1 },
    {}
  )

  -- filter out extraneous extmarks caused by deletion of lines
  local extmarks = resultsList.filterDeletedLinesExtmarks(all_extmarks)

  local locations = {}
  for i = 1, #extmarks do
    local markId, row = unpack(extmarks[i])

    -- get the associated location info
    local location = context.state.resultLocationByExtmarkId[markId]
    if location and location.rgResultLine then
      -- get the current text on row
      local bufline = unpack(vim.api.nvim_buf_get_lines(buf, row, row + 1, true))
      -- ignore ones where user has messed with row:col: prefix
      local numColPrefix = string.sub(location.rgResultLine, 1, location.rgColEndIndex + 1)
      if vim.startswith(bufline, numColPrefix) then
        table.insert(locations, location)
      end
    end
  end

  return locations
end

--- opens all locations in the results area in a quickfix list
---@param params { buf: integer, context: GrugFarContext }
local function qflist(params)
  local buf = params.buf
  local context = params.context
  local state = context.state

  if utils.isMultilineSearchReplace(context) then
    state.actionMessage = 'quickfix list disabled for multline search!'
    renderResultsHeader(buf, context)
    vim.notify('grug-far: ' .. state.actionMessage, vim.log.levels.INFO)
    return
  end

  local resultsLocations = getResultsLocations(buf, context)
  if #resultsLocations == 0 then
    return
  end

  openQuickfixList(context, resultsLocations)
end

return qflist
