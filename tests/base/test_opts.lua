local opts = require('grug-far.opts')
local MiniTest = require('mini.test')
local expect = MiniTest.expect

describe('with_defaults', function()
  it('can properly override spinnerStates', function()
    local expectedOpts = opts.with_defaults({}, opts.defaultOptions)
    local spinnerStates = { 'SPINNING' }
    expectedOpts.spinnerStates = vim.deepcopy(spinnerStates)

    expect.equality(
      opts.with_defaults({ spinnerStates = spinnerStates }, opts.defaultOptions),
      expectedOpts
    )
  end)
end)
