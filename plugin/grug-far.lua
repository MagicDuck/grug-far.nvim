if vim.fn.has('nvim-0.9.0') == 0 then
  vim.api.nvim_err_writeln('grug-far is guaranteeed to work on at least nvim-0.9.0')
  return
end

-- make sure this file is loaded only once
if vim.g.loaded_grug_far == 1 then
  return
end
vim.g.loaded_grug_far = 1
