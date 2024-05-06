local parseResults = require('grug-far/rg/parseResults')
local getArgs = require('grug-far/rg/getArgs')
local uv = vim.loop

local function fetchResults(params)
  local on_fetch_chunk = params.on_fetch_chunk
  local on_finish = params.on_finish
  local inputs = params.inputs
  local options = params.options
  local isAborted = false
  local errorMessage = ''

  local args = getArgs(inputs, options)
  if not args then
    on_finish(nil)
    return
  end

  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

  local handle, pid
  handle, pid = uv.spawn("rg", {
    stdio = { nil, stdout, stderr },
    cwd = vim.fn.getcwd(),
    args = args
  }, function(code, signal)
    stdout:close()
    stderr:close()
    handle:close()
    local isSuccess = code == 0 and #errorMessage == 0
    on_finish(isSuccess and 'success' or 'error', errorMessage);
  end)

  local on_abort = function()
    isAborted = true
    stdout:close()
    stderr:close()
    handle:close()
    uv.kill(pid, 'sigkill')
  end

  uv.read_start(stdout, function(err, data)
    if isAborted then
      return
    end

    if err then
      errorMessage = errorMessage .. '\nrg fetcher: error reading from rg stdout!'
      return
    end

    if data then
      on_fetch_chunk(parseResults(data))
    end
  end)

  uv.read_start(stderr, function(err, data)
    if isAborted then
      return
    end

    if err then
      errorMessage = errorMessage .. '\nrg fetcher: error reading from rg stderr!'
      return
    end

    if data then
      errorMessage = errorMessage .. data
    end
  end)

  return on_abort
end

return fetchResults
