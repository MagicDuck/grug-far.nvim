vim.cmd([[let &rtp.=','.getcwd()]])
vim.cmd('set rtp+=deps/mini.nvim')

Helpers = require('grug-far/test/helpers')
GrugFar = require('grug-far')
GrugFar.setup(Helpers.getSetupOptions())
