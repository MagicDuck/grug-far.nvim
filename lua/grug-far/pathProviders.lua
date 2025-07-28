local M = {}

--- get list of paths corresponding to opened buffers
---@return string[]
M.getBuflistFiles = function()
  local paths = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local buftype = vim.api.nvim_get_option_value('buftype', { buf = buf })
    local buflisted = vim.api.nvim_get_option_value('buflisted', { buf = buf })
    local path = vim.api.nvim_buf_get_name(buf)
    if buftype == '' and buflisted and path and #path > 0 then
      table.insert(paths, path)
    end
  end
  return paths
end

--- get list of paths corresponding to opened buffers that are relative to CWD
---@return string[]
M.getBuflistFilesInCWD = function()
  local list = require('grug-far.pathProviders').getBuflistFiles()
  local cwd = vim.fn.getcwd()
  return vim
    .iter(list)
    :filter(function(path)
      local absPath = vim.fs.abspath(path)
      local relPath = vim.fs.relpath(cwd, absPath)
      return not not relPath
    end)
    :totable()
end

--- get list of paths corresponding to files in quickfix list
---@return string[]
M.getQuickfixListFiles = function()
  local paths = {}
  for _, item in ipairs(vim.fn.getqflist()) do
    local path = vim.api.nvim_buf_get_name(item.bufnr)
    table.insert(paths, path)
  end
  return paths
end

--- get list of paths corresponding to files in loclist for the given window
---@param win integer
---@return string[]
M.getLoclistFiles = function(win)
  local paths = {}
  for _, item in ipairs(vim.fn.getloclist(win)) do
    local path = vim.api.nvim_buf_get_name(item.bufnr)
    table.insert(paths, path)
  end
  return paths
end

return M
