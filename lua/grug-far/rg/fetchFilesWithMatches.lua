local getArgs = require('grug-far/rg/getArgs')
local fetchWithRg = require('grug-far/rg/fetchWithRg')

-- TODO (sbadragan): need to figure where to show this in the UI, aborting, etc
-- possibly in the results list header, show "Applying changes, buffer not modifiable meanwhile"
-- and set nomodifiable for buffer
-- need to call this with proper params from somewhere
local function fetchFilesWithMatches(params)
  local filesWithMatches = ""

  local args = getArgs(params.inputs, params.options)
  if args then
    table.insert(args, '--files-with-matches')
  end

  return fetchWithRg({
    args = args,
    on_fetch_chunk = function(data)
      filesWithMatches = filesWithMatches .. data
      params.on_fetch_chunk(data)
    end,
    on_finish = function(status, errorMessage)
      local lines = vim.split(filesWithMatches, "\n")
      local files = vim.tbl_filter(function(f)
        return #f > 0
      end, lines)
      params.on_finish(status, errorMessage, files)
    end
  })
end

return fetchFilesWithMatches
