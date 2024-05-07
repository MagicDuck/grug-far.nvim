local getArgs = require('grug-far/rg/getArgs')
local fetchWithRg = require('grug-far/rg/fetchWithRg')

local function fetchFilesWithMatches(params)
  local filesWithMatches = {}

  local args = getArgs(params.inputs, params.options)
  if args then
    table.insert(args, '--files-with-matches')
  end

  return fetchWithRg({
    args = args,
    on_fetch_chunk = function(data)
      local lines = vim.split(data, "\n")
      for i = 1, #lines do
        if #lines[i] > 0 then
          table.insert(filesWithMatches, lines[i])
        end
      end
      params.on_fetch_chunk(lines)
    end,
    on_finish = function(status, errorMessage)
      params.on_finish(status, errorMessage, filesWithMatches)
    end
  })
end

return fetchFilesWithMatches
