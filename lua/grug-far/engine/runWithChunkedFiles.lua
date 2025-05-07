--- performs replacement in given matched file
---@param params {
--- files: string[],
--- chunk_size: integer,
--- options: grug.far.Options,
--- run_chunk: fun(chunk: string, on_done: fun(errorMessage: string?)): (abort: fun()?),
--- on_finish: fun(status: grug.far.Status, errorMessage: string?),
---}
local function runWithChunkedFiles(params)
  local chunks = {}
  local current_chunk = nil
  for i = 1, #params.files do
    current_chunk = current_chunk == nil and params.files[i]
      or current_chunk .. '\n' .. params.files[i]
    if i == #params.files or i % params.chunk_size == 0 then
      table.insert(chunks, current_chunk)
      current_chunk = nil
    end
  end

  local on_finish = params.on_finish
  local engagedWorkers = 0
  local errorMessage = nil
  local isAborted = false
  local abortByChunk = {}

  local function abortAll()
    isAborted = true
    for _, abort in pairs(abortByChunk) do
      if abort then
        abort()
      end
    end
  end

  local function handleNextChunk()
    if isAborted then
      chunks = {}
    end

    local chunk = table.remove(chunks)
    if chunk == nil then
      if engagedWorkers == 0 then
        if errorMessage then
          on_finish('error', errorMessage)
        elseif isAborted then
          on_finish(nil, nil)
        else
          on_finish('success', nil)
        end
      end
      return
    end

    engagedWorkers = engagedWorkers + 1
    abortByChunk[chunk] = params.run_chunk(
      chunk,
      vim.schedule_wrap(function(err)
        abortByChunk[chunk] = nil
        if err then
          errorMessage = err
          abortAll()
        end

        engagedWorkers = engagedWorkers - 1
        handleNextChunk()
      end)
    )
  end

  for _ = 1, params.options.maxWorkers do
    handleNextChunk()
  end

  return abortAll
end

return runWithChunkedFiles
