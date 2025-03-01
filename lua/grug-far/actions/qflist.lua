local utils = require('grug-far.utils')

--- opens quickfix list
---@param buf integer
---@param context GrugFarContext
---@param resultsLocations ResultLocation[]
local function openQuickfixList(buf, context, resultsLocations)
  vim.fn.setqflist(resultsLocations, ' ')
  vim.fn.setqflist({}, 'a', {
    title = 'Grug FAR results' .. utils.strEllideAfter(
      context.engine.getSearchDescription(context.state.inputs),
      context.options.maxSearchCharsInTitles,
      ' for: '
    ),
  })

  -- open/goto target win so that quickfix list will open items into the terget win
  local targetWin, isNewWin = utils.getOpenTargetWin(context, buf)
  vim.api.nvim_set_current_win(targetWin)

  -- open list below taking whole horizontal space
  vim.cmd('botright copen | stopinsert')
  if isNewWin then
    vim.api.nvim_set_current_win(targetWin)
    vim.cmd('cfirst')
  end
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

  openQuickfixList(buf, context, resultsLocations)
end

return qflist
