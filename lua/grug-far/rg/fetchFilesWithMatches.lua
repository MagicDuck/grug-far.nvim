local getArgs = require('grug-far/rg/getArgs')
local uv = vim.loop

-- TODO (sbadragan): need to figure where to show this in the UI, aborting, etc
-- possibly in the results list header, show "Applying changes, buffer not modifiable meanwhile"
-- and set nomodifiable for buffer
-- need to call this with proper params from somewhere
-- TODO (sbadragan): need to figure out a 'fetchWithRg' higher order function that's used in all those fetchers since there will
-- be another passthrough one
local function fetchFilesWIthMatches(params)
  P('------replacing')
  local on_finish = params.on_finish
  local on_error = params.on_error
  local on_progress = params.on_progress
  local inputs = params.inputs
  local options = params.options
  local isAborted = false
  local filesWithMatches = {}

  -- TODO (sbadragan): no color
  local args = getArgs(inputs, options)
  if not args then
    on_finish(nil)
    return
  end

  table.insert(args, '--files-with-matches')

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
    on_finish(isSuccess and 'success' or 'error', filesWithMatches);
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
      on_error('rg replace: error reading from rg stdout!')
      return
    end

    if data then
      local lines = vim.fn.split(data, "\n")
      for i = 1, #lines do
        table.insert(filesWithMatches, lines[i])
      end

      on_progress()
    end
  end)

  uv.read_start(stderr, function(err, data)
    if isAborted then
      return
    end

    if err then
      on_error('rg replace: error reading from rg stderr!')
      return
    end

    if data then
      on_error(data)
    end
  end)
end

return replace
