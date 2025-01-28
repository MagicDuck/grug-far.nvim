local M = {}

---@alias GrugFarTaskType 'search' | 'sync' | 'replace'

---@class GrugFarTask
---@field id number
---@field type GrugFarTaskType
---@field abort? fun()
---@field isFinished boolean

local last_task_id = 0
local function get_next_task_id()
  last_task_id = last_task_id + 1
  return last_task_id
end

--- creates new task
---@param context GrugFarContext
---@param type GrugFarTaskType
---@param abort? fun()
---@return GrugFarTask
function M.createTask(context, type, abort)
  local task = {
    id = get_next_task_id(),
    isFinished = false,
    abort = abort,
    type = type,
  }

  table.insert(context.state.tasks, task)
  return task
end

--- gets active tasks by type
---@param context GrugFarContext
---@param type GrugFarTaskType
---@return GrugFarTask[]
function M.getActiveTasksByType(context, type)
  return vim
    .iter(context.state.tasks)
    :filter(function(task)
      return not task.isFinished and task.type == type
    end)
    :totable()
end

--- checks if there are any active tasks with given type
---@param context GrugFarContext
---@param type GrugFarTaskType
---@return boolean
function M.hasActiveTasksWithType(context, type)
  return #M.getActiveTasksByType(context, type) > 0
end

local function _abortTask(task)
  if task.isFinished then
    return
  end

  task.isFinished = true
  if task.abort then
    task.abort()
  end
end

--- aborts all tasks
---@param context GrugFarContext
function M.abortAllTasks(context)
  for _, task in ipairs(context.state.tasks) do
    _abortTask(task)
  end
  context.state.tasks = {}
end

--- aborts given tasks
---@param context GrugFarContext
---@param task GrugFarTask
function M.abortTask(context, task)
  _abortTask(task)
  context.state.tasks = vim
    .iter(context.state.tasks)
    :filter(function(t)
      return t == task
    end)
    :totable()
end

--- finishes given task
---@param context GrugFarContext
---@param task GrugFarTask
function M.finishTask(context, task)
  task.isFinished = true
  context.state.tasks = vim
    .iter(context.state.tasks)
    :filter(function(t)
      return t == task
    end)
    :totable()
end

function M.task_callback_wrap(context, task, cb)
  return function(...)
    if context.state.bufClosed then
      return
    end
    if task.isFinished then
      return
    end

    cb(...)
  end
end

return M
