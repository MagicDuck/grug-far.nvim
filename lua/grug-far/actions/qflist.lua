local utils = require('grug-far.utils')
local inputs = require('grug-far.inputs')

--- opens quickfix list
---@param buf integer
---@param context grug.far.Context
---@param resultsLocations grug.far.ResultLocation[]
local function openQuickfixList(buf, context, resultsLocations)
  vim.fn.setqflist(resultsLocations, ' ')
  vim.fn.setqflist({}, 'a', {
    title = 'Grug FAR results' .. utils.strEllideAfter(
      context.engine.getSearchDescription(inputs.getValues(context, buf)),
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
---@param context grug.far.Context
---@return grug.far.ResultLocation[]
local function getResultsLocations(context)
  local extmarks = vim.api.nvim_buf_get_extmarks(
    0,
    context.locationsNamespace,
    { 0, 0 },
    { -1, -1 },
    { details = true }
  )

  local locations = {}
  for _, mark in ipairs(extmarks) do
    local markId, _, _, details = unpack(mark)

    -- get the associated location info
    local location = context.state.resultLocationByExtmarkId[markId]
    if (not details.invalid) and location and location.text and location.col then
      table.insert(locations, location)
    end
  end

  return locations
end

--- opens all locations in the results area in a quickfix list
---@param params { buf: integer, context: grug.far.Context }
local function qflist(params)
  local buf = params.buf
  local context = params.context

  local resultsLocations = getResultsLocations(context)
  if #resultsLocations == 0 then
    return
  end

  openQuickfixList(buf, context, resultsLocations)
end

return qflist
