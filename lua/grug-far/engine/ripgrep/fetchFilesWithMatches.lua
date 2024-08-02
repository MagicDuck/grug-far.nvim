local getArgs = require('grug-far/engine/ripgrep/getArgs')
local blacklistedReplaceFlags = require('grug-far/engine/ripgrep/blacklistedReplaceFlags')
local fetchWithRg = require('grug-far/engine/ripgrep/fetchWithRg')

---@class FetchWithMatchesParams
---@field inputs GrugFarInputs
---@field options GrugFarOptions
---@field on_fetch_chunk fun(data: string[])
---@field on_finish fun(status: GrugFarStatus, errorMesage: string | nil, filesWithMatches: string[], blacklistedArgs: string[] | nil)

--- fetch list of files that match search
---@param params FetchWithMatchesParams
---@return nil | fun() abort
local function fetchFilesWithMatches(params)
  local filesWithMatches = {}

  local args, blacklistedArgs = getArgs(params.inputs, params.options, {
    '--files-with-matches',
    '--color=never',
  }, blacklistedReplaceFlags)

  return fetchWithRg({
    args = args,
    options = params.options,
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
