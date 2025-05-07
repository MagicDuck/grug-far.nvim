local utils = require('grug-far.utils')
local uv = vim.uv

--- fetch with ripgrep
---@param params {
--- cmd_path: string,
--- args: string[]?,
--- on_fetch_chunk: fun(data: string),
--- on_finish: fun(status: grug.far.Status, errorMessage: string?),
--- stdin?: uv_pipe_t,
--- fixChunkLineTruncation?: boolean,
--- }
---@return fun()? abort, string[]? effectiveArgs
local function fetchCommandOutput(params)
  local args = params.args
  local finished = false
  local errorMessage = ''

  local lastLine = ''
  local on_fetch_chunk = params.on_fetch_chunk
  local on_finish = function(...)
    if #lastLine > 0 then
      on_fetch_chunk(lastLine)
      lastLine = ''
    end
    params.on_finish(...)
  end
  local fixChunkLineTruncation = not (params.fixChunkLineTruncation == false)

  if not args then
    on_finish(nil, nil)
    return nil, args
  end

  local stdin = params.stdin
  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()
  local hadStdout = false

  local handle
  handle = uv.spawn(params.cmd_path, {
    stdio = { stdin, stdout, stderr },
    cwd = vim.fn.getcwd(),
    args = args,
  }, function(
    code -- ,signal
  )
    if finished then
      return
    end

    utils.closeHandle(stdin)
    utils.closeHandle(stdout)
    utils.closeHandle(stderr)
    utils.closeHandle(handle)

    vim.schedule(function()
      finished = true
      -- note: when no stdout, we report errors with a message as warnings (status = success) since
      -- for example ripgrep can generate errors only for a particular file (like permission denied
      -- but everything else succeeded
      local isSuccess = code == 0 or (hadStdout and errorMessage and #errorMessage > 0)
      on_finish(isSuccess and 'success' or 'error', errorMessage)
    end)
  end)

  local on_abort = function()
    if finished then
      return
    end

    finished = true
    utils.closeHandle(stdin)
    utils.closeHandle(stdout)
    utils.closeHandle(stderr)
    utils.closeHandle(handle)
    if handle then
      handle:kill(vim.uv.constants.SIGTERM)
    end

    vim.schedule(function()
      on_finish(nil, nil)
    end)
  end

  uv.read_start(
    stdout,
    vim.schedule_wrap(function(err, data)
      if finished then
        return
      end

      if err then
        errorMessage = errorMessage .. '\nerror reading from command stdout!'
        return
      end
      if fixChunkLineTruncation then
        if data then
          hadStdout = true

          -- large outputs can cause the last line to be truncated
          -- save it and prepend to next chunk
          local chunkData = lastLine .. data
          chunkData, lastLine = utils.splitLastLine(chunkData)
          if #chunkData > 0 then
            on_fetch_chunk(chunkData)
          end
        else
          on_fetch_chunk(lastLine)
        end
      else
        if data then
          hadStdout = true
          on_fetch_chunk(data)
        end
      end
    end)
  )

  uv.read_start(
    stderr,
    vim.schedule_wrap(function(err, data)
      if finished then
        return
      end

      if err then
        errorMessage = errorMessage .. '\nerror reading from command stderr!'
        return
      end

      if data then
        errorMessage = errorMessage .. data
      end
    end)
  )

  return on_abort, args
end

return fetchCommandOutput
