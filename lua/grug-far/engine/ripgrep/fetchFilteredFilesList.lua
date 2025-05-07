local getArgs = require('grug-far.engine.ripgrep.getArgs')
local fetchCommandOutput = require('grug-far.engine.fetchCommandOutput')

--- fetch list of files that match filter and paths
---@param params {
--- inputs: grug.far.Inputs,
--- options: grug.far.Options,
--- report_progress: fun(count: integer),
--- on_finish: fun(status: grug.far.Status, errorMessage: string?, files: string[]),
--- }
---@return fun()? abort
local function fetchFilesList(params)
  local files = {}
  local inputs = params.inputs
  local options = vim.deepcopy(params.options)
  options.minSearchChars = 0

  local args = getArgs(
    {
      search = '',
      replacement = '',
      flags = '',
      filesFilter = inputs.filesFilter,
      paths = inputs.paths,
    },
    options,
    {
      '--files',
      '--color=never',
    }
  )

  return fetchCommandOutput({
    cmd_path = params.options.engines.ripgrep.path,
    args = args,
    on_fetch_chunk = function(data)
      local lines = vim.split(data, '\n')
      local count = 0
      for i = 1, #lines do
        if #lines[i] > 0 then
          table.insert(files, lines[i])
          count = count + 1
        end
      end
      params.report_progress(count)
    end,
    on_finish = function(status, errorMessage)
      params.on_finish(status, errorMessage, files)
    end,
  })
end

return fetchFilesList
