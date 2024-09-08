local utils = require('grug-far/utils')
local uv = vim.uv

---@class FetchCommandOutputParams
---@field cmd_path string
---@field args string[]?
---@field on_fetch_chunk fun(data: string)
---@field on_finish fun(status: GrugFarStatus, errorMesage: string?)
---@field stdin? uv_pipe_t

--- fetch with ripgrep
---@param params FetchCommandOutputParams
---@return fun()? abort, string[]? effectiveArgs
local function fetchCommandOutput(params)
  local args = params.args
  local finished = false
  local errorMessage = ''

  local on_fetch_chunk = params.on_fetch_chunk
  local on_finish = params.on_finish

  if not args then
    on_finish(nil, nil)
    return nil, args
  end

  local stdin = params.stdin
  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

  local handle
  handle = uv.spawn(params.cmd_path, {
    stdio = { nil, stdout, stderr },
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

    local isSuccess = code == 0
    if not isSuccess then
      -- finish immediately if error, so no more result updates are sent out to the consumer
      finished = true
    end

    vim.schedule(function()
      finished = true
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

  local lastLine = ''
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

      if data then
        -- large outputs can cause the last line to be truncated
        -- save it and prepend to next chunk
        local chunkData = lastLine .. data
        chunkData, lastLine = utils.splitLastLine(chunkData)
        if #chunkData > 0 then
          on_fetch_chunk(chunkData)
        end
      else
        if #lastLine > 0 then
          on_fetch_chunk(lastLine)
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
