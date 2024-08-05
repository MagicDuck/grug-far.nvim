local MiniTest = require('mini.test')
local file = vim.env.file
local line = vim.env.line
local dir = vim.env.dir
local group_depth = vim.env.group_depth

if file then
  if line then
    MiniTest.run_at_location({
      file = file,
      line = tonumber(line),
    }, {
      execute = {
        reporter = MiniTest.gen_reporter.stdout({ group_depth = group_depth }),
      },
    })
  else
    MiniTest.run_file(file)
  end
else
  if dir then
    MiniTest.run({
      collect = {
        find_files = function()
          return vim.fn.globpath('tests/' .. dir, '**/test_*.lua', true, true)
        end,
      },
    })
  else
    MiniTest.run()
  end
end
