local getArgs = require('grug-far.engine.ripgrep.getArgs')
local blacklistedReplaceFlags = require('grug-far.engine.ripgrep.blacklistedReplaceFlags')
local fetchCommandOutput = require('grug-far.engine.fetchCommandOutput')

--- fetch list of files that match search
---@param params {
--- inputs: grug.far.Inputs,
--- options: grug.far.Options,
--- report_progress: fun(count: integer),
--- on_finish: fun(status: grug.far.Status, errorMessage: string?, filesWithMatches: string[], blacklistedArgs: string[]?)
---}
---@return fun()? abort
local function fetchFilesWithMatches(params)
  local filesWithMatches = {}

  local args, blacklistedArgs = getArgs(params.inputs, params.options, {
    '--files-with-matches',
    '--color=never',
  }, blacklistedReplaceFlags)

  return fetchCommandOutput({
    cmd_path = params.options.engines.ripgrep.path,
    args = args,
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
