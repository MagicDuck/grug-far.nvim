local getArgs = require('grug-far/rg/getArgs')
local blacklistedReplaceFlags = require('grug-far/rg/blacklistedReplaceFlags')
local fetchWithRg = require('grug-far/rg/fetchWithRg')

local function fetchFilesWithMatches(params)
  local filesWithMatches = {}

  local args, blacklistedArgs = getArgs(params.inputs, params.options, {
    '--files-with-matches',
    '--color=never',
  }, blacklistedReplaceFlags)

  return fetchWithRg({
    args = args,
    on_fetch_chunk = function(data)
      local lines = vim.split(data, '\n')
      for i = 1, #lines do
        if #lines[i] > 0 then
          table.insert(filesWithMatches, lines[i])
        end
      end
      params.on_fetch_chunk(lines)
    end,
    on_finish = function(status, errorMessage)
      params.on_finish(status, errorMessage, filesWithMatches, blacklistedArgs)
    end,
  })
end

return fetchFilesWithMatches
