local M = {}

---@alias grug.far.AsyncJob fun(on_finish: fun(status?: grug.far.Status, errorMessage?: string, ...), ...): (abort: fun()?)
---@alias grug.far.AsyncJobOneParam<T> fun(on_finish: fun(status?: grug.far.Status, errorMessage?: string), arg: T): (abort: fun()?)

--- chains 2 async jobs
---@param job1? grug.far.AsyncJob
---@param job2? grug.far.AsyncJob
---@return grug.far.AsyncJob?
local function chain2(job1, job2)
  if job1 == nil then
    return job2
  end
  if job2 == nil then
    return job1
  end
  return function(on_finish, ...)
    local on_abort = nil
    local isAborted = false
    local function abort()
      if isAborted then
        return
      end
      isAborted = true

      if on_abort then
        on_abort()
      end
      on_abort = nil
    end
    local aggregateErrorMessage = ''
    local function _on_finish(status, errorMessage, ...)
      on_abort = nil
      if isAborted then
        return
      end
      if errorMessage then
        aggregateErrorMessage = aggregateErrorMessage .. '\n' .. errorMessage
      end
      on_finish(status, errorMessage, ...)
    end

    on_abort = job1(function(status, errorMessage, ...)
      if isAborted then
        return
      end
      if status == nil or status == 'error' then
        _on_finish(status, errorMessage, ...)
      else
        if errorMessage then
          aggregateErrorMessage = aggregateErrorMessage .. '\n' .. errorMessage
        end
        on_abort = job2(_on_finish, ...)
      end
    end, ...)

    return abort
  end
end

--- chains together multiple async jobs
---@vararg grug.far.AsyncJob
---@return grug.far.AsyncJob
function M.chain(...)
  local result = nil
  for i = 1, select('#', ...) do
    local job = select(i, ...)
    result = chain2(result, job)
  end

  if result == nil then
    return function() end
  else
    return result
  end
end

---@generic T
---@param params {
--- items: T[],
--- maxWorkers: integer,
--- process_item: grug.far.AsyncJobOneParam<T>,
--- on_finish: fun(status: grug.far.Status, errorMessage: string?),
---}
---@return fun() abort
function M.parallel_process(params)
  local items = vim.fn.copy(params.items)

  local on_finish = params.on_finish
  local engagedWorkers = 0
  local errorMessage = nil
  local isAborted = false
  local abortByItem = {}

  local function abortAll()
    isAborted = true
    for _, abort in pairs(abortByItem) do
      if abort then
        abort()
      end
    end
  end

  local function handleNextItem()
    if isAborted then
      items = {}
    end

    local item = table.remove(items)
    if item == nil then
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
    abortByItem[item] = params.process_item(
      vim.schedule_wrap(function(status, err)
        abortByItem[item] = nil
        if status == 'error' then
          errorMessage = err or 'unexpected error'
          abortAll()
        end

        engagedWorkers = engagedWorkers - 1
        handleNextItem()
      end),
      item
    )
  end

  for _ = 1, params.maxWorkers do
    handleNextItem()
  end

  return abortAll
end

return M
