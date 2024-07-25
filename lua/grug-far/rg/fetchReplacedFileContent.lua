local getArgs = require('grug-far/rg/getArgs')
local blacklistedReplaceFlags = require('grug-far/rg/blacklistedReplaceFlags')
local fetchWithRg = require('grug-far/rg/fetchWithRg')

---@class FetchReplacedFileContentParams
---@field inputs GrugFarInputs
---@field options GrugFarOptions
---@field file string
---@field on_finish fun(status: GrugFarStatus, errorMesage: string | nil, content: string)

--- fetch file content with matches replaced
---@param params FetchReplacedFileContentParams
---@return nil | fun() abort
local function fetchReplacedFileContent(params)
  local extraFlags = {
    '--passthrough',
    '--no-line-number',
    '--no-column',
    '--color=never',
    '--no-heading',
    '--no-filename',
  }

  local inputs = vim.deepcopy(params.inputs)
  inputs.paths = ''
  local args = getArgs(inputs, params.options, extraFlags, blacklistedReplaceFlags, true)
  if args then
    table.insert(args, params.file)
  end

  local content = ''
  return fetchWithRg({
    args = args,
    options = params.options,
    on_fetch_chunk = function(data)
      content = content .. data
    end,
    on_finish = function(status, errorMessage)
      params.on_finish(status, errorMessage, content)
    end,
  })
end

return fetchReplacedFileContent
