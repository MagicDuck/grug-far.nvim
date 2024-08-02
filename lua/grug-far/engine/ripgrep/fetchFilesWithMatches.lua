local getArgs = require('grug-far/engine/ripgrep/getArgs')
local blacklistedReplaceFlags = require('grug-far/engine/ripgrep/blacklistedReplaceFlags')
local fetchCommandOutput = require('grug-far/engine/fetchCommandOutput')

---@class FetchWithMatchesParams
---@field inputs GrugFarInputs
---@field options GrugFarOptions
---@field report_progress fun(count: integer)
---@field on_finish fun(status: GrugFarStatus, errorMesage: string?, filesWithMatches: string[], blacklistedArgs: string[]?)

--- fetch list of files that match search
---@param params FetchWithMatchesParams
---@return fun()? abort
local function fetchFilesWithMatches(params)
  local filesWithMatches = {}

  local args, blacklistedArgs = getArgs(params.inputs, params.options, {
    '--files-with-matches',
    '--color=never',
  }, blacklistedReplaceFlags)

  return fetchCommandOutput({
    cmd_path = params.options.rgPath,
    args = args,
    options = params.options,
    on_fetch_chunk = function(data)
      local lines = vim.split(data, '\n')
      local count = 0
      for i = 1, #lines do
        if #lines[i] > 0 then
          table.insert(filesWithMatches, lines[i])
          count = count + 1
        end
      end
      params.report_progress(count)
    end,
    on_finish = function(status, errorMessage)
      params.on_finish(status, errorMessage, filesWithMatches, blacklistedArgs)
    end,
  })
end

return fetchFilesWithMatches
