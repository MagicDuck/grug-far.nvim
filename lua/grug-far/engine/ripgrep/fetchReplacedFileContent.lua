local getArgs = require('grug-far.engine.ripgrep.getArgs')
local utils = require('grug-far.utils')
local blacklistedReplaceFlags = require('grug-far.engine.ripgrep.blacklistedReplaceFlags')
local uv = vim.uv

--- fetch file content with matches replaced
---@param params {
--- inputs: grug.far.Inputs,
--- options: grug.far.Options,
--- file: string,
--- on_finish: fun(status: grug.far.Status, errorMessage: string | nil, content: string?),
--- }
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
  local finished = false

  local handle
  handle = uv.spawn(params.options.engines.ripgrep.path, {
    stdio = { nil, stdout, stderr },
    cwd = vim.fn.getcwd(),
    args = args,
  }, function(
    code -- ,signal
  )
    if finished then
      return
    end

    utils.closeHandle(stdout)
    utils.closeHandle(stderr)
    utils.closeHandle(handle)

    finished = true
    local isSuccess = code == 0
    on_finish(isSuccess and 'success' or 'error', errorMessage, content)
  end)

  uv.read_start(stdout, function(err, data)
    if finished then
      return
    end
    if err then
      errorMessage = errorMessage .. '\nerror reading from rg stdout!'
      return
    end

    if data then
      if content then
        content = content .. data
      else
        content = data
      end
    end
  end)

  uv.read_start(stderr, function(err, data)
    if finished then
      return
    end
    if err then
      errorMessage = errorMessage .. '\nerror reading from rg stderr!'
      return
    end

    if data then
      errorMessage = errorMessage .. data
    end
  end)

  local on_abort = function()
    if finished then
      return
    end

    finished = true
    utils.closeHandle(stdout)
    utils.closeHandle(stderr)
    utils.closeHandle(handle)
    if handle then
      handle:kill(vim.uv.constants.SIGTERM)
    end

    on_finish(nil, nil, nil)
  end

  return on_abort
end

return fetchReplacedFileContent
