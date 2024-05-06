local getArgs = require('grug-far/rg/getArgs')
local fetchWithRg = require('grug-far/rg/fetchWithRg')

-- TODO (sbadragan): need to figure where to show this in the UI, aborting, etc
-- possibly in the results list header, show "Applying changes, buffer not modifiable meanwhile"
-- and set nomodifiable for buffer
-- need to call this with proper params from somewhere
local function fetchFilesWithMatches(params)
  local filesWithMatches = {}

  -- TODO (sbadragan): no color
  local args = getArgs(params.inputs, params.options)
  if args then
    table.insert(args, '--files-with-matches')
  end

  return fetchWithRg({
    args = args,
    on_fetch_chunk = function(data)
      local lines = vim.fn.split(data, "\n")
      for i = 1, #lines do
        table.insert(filesWithMatches, lines[i])
      end
      params.on_fetch_chunk(lines)
    end,
    on_finish = params.on_finish
  })
end

return fetchFilesWithMatches
