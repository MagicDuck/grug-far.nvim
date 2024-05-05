local parseResults = require('grug-far/rg/parseResults')
local getArgs = require('grug-far/rg/getArgs')
local uv = vim.loop

local function fetchResults(params)
  local on_fetch_chunk = params.on_fetch_chunk
  local on_finish = params.on_finish
  local on_error = params.on_error
  local inputs = params.inputs

  -- TODO (sbadragan): minimum search ?
  -- if yes control from higher level and only send here wehn > minsize
  local args = getArgs(inputs)
  if not args then
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
    local isSuccess = code == 0
    on_finish(isSuccess);
  end)

  local on_abort = function()
    stdout:close()
    stderr:close()
    handle:close()
    uv.kill(pid, 'sigkill')
  end

  uv.read_start(stdout, function(err, data)
    if err then
      on_error('rg fetcher: error reading from rg stdout!')
      return
    end

    if data then
      on_fetch_chunk(parseResults(data))
    end
  end)

  uv.read_start(stderr, function(err, data)
    if err then
      on_error('rg fetcher: error reading from rg stderr!')
      return
    end

    if data then
      on_error(data)
    end
  end)

  return on_abort
end

return fetchResults
