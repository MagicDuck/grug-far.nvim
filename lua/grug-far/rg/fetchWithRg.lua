local utils = require('grug-far/utils')
local uv = vim.loop

---@param handle uv_handle_t | nil
local function closeHandle(handle)
  if handle and not handle:is_closing() then
    handle:close()
  end
end

---@class FetchWithRgParams
---@field args string[] | nil
---@field on_fetch_chunk fun(data: string)
---@field on_finish fun(status: GrugFarStatus, errorMesage: string | nil)

--- fetch with ripgrep
---@param params FetchWithRgParams
---@return nil | fun() abort
local function fetchWithRg(params)
  local on_fetch_chunk = params.on_fetch_chunk
  local on_finish = params.on_finish
  local args = params.args
  local finished = false
  local errorMessage = ''

  if not args then
    on_finish(nil, nil)
    return nil
  end

  local stdout = uv.new_pipe()
  local stderr = uv.new_pipe()

  local handle
  handle = uv.spawn('rg', {
    stdio = { nil, stdout, stderr },
    cwd = vim.fn.getcwd(),
    args = args,
  }, function(
    code -- ,signal
  )
    if finished then
      return
    end

    finished = true
    closeHandle(stdout)
    closeHandle(stderr)
    closeHandle(handle)

    if code > 0 and #errorMessage == 0 then
      errorMessage = 'no matches'
    end
    local isSuccess = code == 0 and #errorMessage == 0

    on_finish(isSuccess and 'success' or 'error', errorMessage)
  end)

  local on_abort = function()
    if finished then
      return
    end

    finished = true
    closeHandle(stdout)
    closeHandle(stderr)
    closeHandle(handle)
    if handle then
      handle:kill(vim.constants.SIGTERM)
    end

    on_finish(nil, nil)
  end

  local lastLine = ''
  uv.read_start(stdout, function(err, data)
    if finished then
      return
    end

    if err then
      errorMessage = errorMessage .. '\nerror reading from rg stdout!'
      return
    end

    if data then
      -- large outputs can cause the last line to be truncated
      -- save it and prepend to next chunk
      local chunkData = lastLine .. data
      local i = utils.strFindLast(chunkData, '\n')
      if i then
        chunkData = string.sub(chunkData, 1, i)
        lastLine = string.sub(chunkData, i + 1, -1)
        on_fetch_chunk(chunkData)
      else
        lastLine = chunkData
      end
    else
      if #lastLine > 0 then
        on_fetch_chunk(lastLine)
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

  return on_abort
end

return fetchWithRg
