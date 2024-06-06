--- closes the buffer, thus freeing resources
---@param params { context: GrugFarContext }
local function close(params)
  local context = params.context
  local state = context.state

  local choice = vim.fn.confirm('Are you sure?', '&yes\n&cancel')
  if choice == 2 then
    error('')
  end
  vim.cmd('stopinsert | bdelete')
end

return close
