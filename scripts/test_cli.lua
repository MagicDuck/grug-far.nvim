-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd([[let &rtp.=','.getcwd()]])

local dependencies = require('grug-far.test.dependencies')
dependencies.checkDependencies()

vim.cmd('set rtp+=deps/mini.nvim')
require('mini.test').setup()
local MiniTest = require('mini.test')
local file = vim.env.file
local line = vim.env.line
local dir = vim.env.dir
local group_depth = vim.env.group_depth

local opts = {}
if dir then
  opts.collect = {
    find_files = function()
      return vim.fn.globpath('tests/' .. dir, '**/test_*.lua', true, true)
    end,
  }
end

if file then
  file = 'tests/' .. (dir and dir .. '/' or '') .. file
  if line then
    opts.execute = {
      reporter = MiniTest.gen_reporter.stdout({ group_depth = group_depth }),
    }
    MiniTest.run_at_location({
      file = file,
      line = tonumber(line),
    }, opts)
  else
    MiniTest.run_file(file, opts)
  end
else
  MiniTest.run(opts)
end
