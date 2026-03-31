local M = {}

---@alias grug.far.AsyncJob fun(resolve: fun(...), reject: fun(...), ...): (abort: fun()?)

--- chains 2 async jobs
---@param job1? grug.far.AsyncJob
---@param job2? grug.far.AsyncJob
---@return grug.far.AsyncJob?
function M.chain2(job1, job2)
  if job1 == nil then
    return job2
  end
  if job2 == nil then
    return job1
  end
  return function(resolve, reject, ...)
    local on_abort = nil
    local function abort()
      if on_abort then
        on_abort()
      end
    end
    local function _resolve(...)
      on_abort = nil
      resolve(...)
    end
    local function _reject(...)
      on_abort = nil
      reject(...)
    end

    on_abort = job1(function(...)
      on_abort = job2(_resolve, _reject, ...)
    end, _reject, ...)

    return abort
  end
end

--- chains together multiple async jobs
---@vararg grug.far.AsyncJob
---@return grug.far.AsyncJob
function M.chain(...)
  local tasks = { ... }
  local result = nil
  for i, task in ipairs(tasks) do
    if i > 1 then
      result = M.chain2(result, task)
    end
  end

  if result == nil then
    return function() end
  else
    return result
  end
end

------------ FOR DEV PURPOSES
-- local async_job = M
--
-- vim.print('starting...')
-- local job = async_job.chain(function(resolve, reject, arg)
--   require('grug-far.utils').setTimeout(function()
--     vim.print('task 1 arg', arg)
--     resolve(123)
--   end, 300)
-- end, function(resolve, reject, arg)
--   require('grug-far.utils').setTimeout(function()
--     vim.print('task 2 arg', arg)
--     resolve(234)
--   end, 100)
-- end)
--
-- job(function(...)
--   vim.print('done, success', ...)
-- end, function(...)
--   vim.print('done, failed', ...)
-- end, 'bob')

return M
