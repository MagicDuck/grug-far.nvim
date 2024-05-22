--- closes the buffer, thus freeing resources
local function close()
  vim.cmd('stopinsert | bdelete')
end

return close
