local utils = require('grug-far/utils')
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
  local extmarks = vim.api.nvim_buf_get_extmarks(
    0,
    context.locationsNamespace,
    { 0, 0 },
    { -1, -1 },
    { details = true }
  )

  local locations = {}
  for _, mark in ipairs(extmarks) do
    local markId, row, _, details = unpack(mark)

    -- get the associated location info
    local location = context.state.resultLocationByExtmarkId[markId]
    if (not details.invalid) and location and location.text and location.col then
      -- get the current text on row
      local bufline = unpack(vim.api.nvim_buf_get_lines(buf, row, row + 1, false))

      -- ignore ones where user has messed with row:col: prefix
      local numColPrefix = string.sub(location.text, 1, location.end_col + 1)
      if bufline and vim.startswith(bufline, numColPrefix) then
        local newLocation = vim.deepcopy(location)
        newLocation.text = string.sub(location.text, #numColPrefix + 1)
        table.insert(locations, newLocation)
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

  local resultsLocations = getResultsLocations(buf, context)
  if #resultsLocations == 0 then
    return
  end

  openQuickfixList(context, resultsLocations)
end

return qflist
