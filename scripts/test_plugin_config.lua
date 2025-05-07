vim.cmd([[let &rtp.=','.getcwd()]])
vim.cmd('set rtp+=deps/mini.nvim')

local helpers = require('grug-far.test.helpers')
local grugFar = require('grug-far')
grugFar.setup(helpers.getSetupOptions())
