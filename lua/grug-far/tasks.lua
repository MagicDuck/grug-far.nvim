local M = {}

---@alias grug.far.TaskType 'search' | 'sync' | 'replace'

---@class grug.far.Task
---@field id number
---@field type grug.far.TaskType
---@field abort? fun()
---@field isAborted boolean
---@field isFinished boolean

local last_task_id = 0
local function get_next_task_id()
  last_task_id = last_task_id + 1
  return last_task_id
end

--- creates new task
---@param context grug.far.Context
---@param type grug.far.TaskType
---@param abort? fun()
---@return grug.far.Task
function M.createTask(context, type, abort)
  local task = {
    id = get_next_task_id(),
    isFinished = false,
    isAborted = false,
    abort = abort,
    type = type,
  }

  table.insert(context.state.tasks, task)
  return task
end

--- gets tasks by type
---@param context grug.far.Context
---@param type grug.far.TaskType
---@return grug.far.Task[]
function M.getTasksByType(context, type)
  return vim
    .iter(context.state.tasks)
    :filter(function(task)
      return task.type == type
    end)
    :totable()
end

--- gets active tasks by type
---@param context grug.far.Context
---@param type grug.far.TaskType
---@return grug.far.Task[]
function M.getActiveTasksByType(context, type)
  return vim
    .iter(context.state.tasks)
    :filter(function(task)
      return not task.isFinished and not task.isAborted and task.type == type
    end)
    :totable()
end

--- checks if there are any active tasks with given type
---@param context grug.far.Context
---@param type grug.far.TaskType
---@return boolean
function M.hasActiveTasksWithType(context, type)
  return #M.getActiveTasksByType(context, type) > 0
end

--- aborts and finishes all tasks
---@param context grug.far.Context
---@return boolean abortedAny
function M.abortAndFinishAllTasks(context)
  local abortedAny = false
  for _, task in ipairs(context.state.tasks) do
    local wasAborted = M.abortTask(task)
    M.finishTask(context, task)
    abortedAny = abortedAny or wasAborted
  end

  return abortedAny
end

--- aborts given tasks
---@param task grug.far.Task
function M.abortTask(task)
  if task.isAborted then
    return false
  end

  task.isAborted = true
  if task.abort then
    task.abort()
  end

  return true
end

--- finishes given task and removes it from the task list
---@param context grug.far.Context
---@param task grug.far.Task
function M.finishTask(context, task)
  task.isFinished = true
  task.isAborted = false
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
    if task.isFinished or task.isAborted then
      return
    end

    cb(...)
  end
end

return M
