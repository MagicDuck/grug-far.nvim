local M = {}

M.__index = M

--- a processing queue processes each item pushed to it in sequence
--- until there are none. If more items are pushed it automatically starts
--- processing again
---@param processCallback fun(item: any, on_done: fun())
function M.new(processCallback)
  local self = setmetatable({}, M)
  self.queue = {}
  self.processCallback = processCallback
  self.is_stopped = false
  return self
end

function M:_processNext()
  if self.is_stopped then
    return
  end

  local item = self.queue[1]
  self.processCallback(item, function()
    table.remove(self.queue, 1)
    if #self.queue > 0 then
      self:_processNext()
    elseif self._on_finish then
      self._on_finish()
    end
  end)
end

--- adds item to be processed to the queue
--- automatically processes as necessary
---@param item any
function M:push(item)
  table.insert(self.queue, item)
  if #self.queue == 1 then
    self:_processNext()
  end
end

--- aggregate to last item in queue
--- automatically processes as necessary
---@param aggregate_callback fun(item?: any): any
function M:aggregate_last(aggregate_callback)
  if #self.queue > 1 then
    self.queue[#self.queue] = aggregate_callback(self.queue[#self.queue])
  else
    table.insert(self.queue, aggregate_callback(nil))
  end

  if #self.queue == 1 then
    self:_processNext()
  end
end

--- stops the processing queue at the first available chance
function M:stop()
  self.is_stopped = true
end

function M:on_finish(callback)
  if #self.queue == 0 then
    callback()
  else
    self._on_finish = callback
  end
end

return M
