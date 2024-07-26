local getArgs = require('grug-far/rg/getArgs')
local utils = require('grug-far/utils')
local blacklistedReplaceFlags = require('grug-far/rg/blacklistedReplaceFlags')
local uv = vim.uv

---@class FetchReplacedFileContentParams
---@field inputs GrugFarInputs
---@field options GrugFarOptions
---@field file string
---@field on_finish fun(status: GrugFarStatus, errorMesage: string | nil, content: string?)

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

  local on_finish = params.on_finish
  if not args then
    on_finish('error', 'invalid args!', nil)
    return nil
  end

  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()
  local errorMessage = ''
  local content = nil

  local handle
  handle = uv.spawn(params.options.rgPath, {
    stdio = { nil, stdout, stderr },
    cwd = vim.fn.getcwd(),
    args = args,
  }, function(
    code -- ,signal
  )
    utils.closeHandle(stdout)
    utils.closeHandle(stderr)
    utils.closeHandle(handle)

    local isSuccess = code == 0
    on_finish(isSuccess and 'success' or 'error', errorMessage, content)
  end)

  uv.read_start(stdout, function(err, data)
    if err then
      errorMessage = errorMessage .. '\nerror reading from rg stdout!'
      return
    end

    if data then
      content = content and data or content .. data
    end
  end)

  uv.read_start(stderr, function(err, data)
    if err then
      errorMessage = errorMessage .. '\nerror reading from rg stderr!'
      return
    end

    if data then
      errorMessage = errorMessage .. data
    end
  end)

  -- TODO (sbadragan): can we get abort in a simple way?
  return nil
end

return fetchReplacedFileContent
