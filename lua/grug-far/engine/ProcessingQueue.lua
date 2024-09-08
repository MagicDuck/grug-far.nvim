local M = {}

M.__index = M

function M.new(processCallback)
  local self = setmetatable({}, M)
  self.queue = {}
  self.processCallback = processCallback
  return self
end

function M:_processNext()
  local item = self.queue[1]
  self.processCallback(item, function()
    table.remove(self.queue, 1)
    if #self.queue > 0 then
      self:_processNext()
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

return M
