local function close()
  vim.cmd('stopinsert | bdelete')
end

return close
