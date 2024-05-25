local MiniTest = require('mini.test')
local file = vim.env.file
local line = vim.env.line
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
  MiniTest.run()
end
