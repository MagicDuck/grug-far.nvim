local M = {}

--- get list of paths corresponding to opened buffers
---@return string[]
M.getBuflistFiles = function()
  local paths = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local buftype = vim.api.nvim_get_option_value('buftype', { buf = buf })
    local buflisted = vim.api.nvim_get_option_value('buflisted', { buf = buf })
    local filetype = vim.api.nvim_get_option_value('filetype', { buf = buf })
    local path = vim.api.nvim_buf_get_name(buf)
    if buftype == '' and buflisted and filetype ~= '' and path then
      table.insert(paths, vim.fn.fnameescape(path))
    end
  end
  return paths
end

--- get list of paths corresponding to files in quickfix list
---@return string[]
M.getQuickfixListFiles = function()
  local paths = {}
  for _, item in ipairs(vim.fn.getqflist()) do
    local path = vim.api.nvim_buf_get_name(item.bufnr)
    table.insert(paths, vim.fn.fnameescape(path))
  end
  return paths
end

-- TODO (sbadragan): do loclist?
-- this one takes the winid, so we would either have to make it operate on prevWin
-- or add a number parameter
-- |getloclist()|.

return M
