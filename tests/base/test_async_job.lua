local async_job = require('grug-far.async_job')
local MiniTest = require('mini.test')
local expect = MiniTest.expect

local alphabet = { 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H' }
local add_job = function(finish, count, str)
  finish('success', nil, count + 1, str .. alphabet[count + 1])
end
local fail_job = function(finish, count, str)
  finish('error', 'job failed at count=' .. count .. ' and str=' .. str)
end

describe('chain', function()
  it('chains together 1 successful job', function()
    async_job.chain(nil, add_job, nil)(function(status, errorMessage, count, str)
      expect.equality(status, 'success')
      expect.equality(errorMessage, nil)
      expect.equality(count, 1)
      expect.equality(str, 'A')
    end, 0, '')
  end)
  it('chains together 3 successful jobs', function()
    async_job.chain(add_job, add_job, add_job)(function(status, errorMessage, count, str)
      expect.equality(status, 'success')
      expect.equality(errorMessage, nil)
      expect.equality(count, 3)
      expect.equality(str, 'ABC')
    end, 0, '')
  end)
  it('deals correctly with failed job in between', function()
    async_job.chain(add_job, fail_job, add_job)(function(status, errorMessage)
      expect.equality(status, 'error')
      expect.equality(errorMessage, 'job failed at count=1 and str=A')
    end, 0, '')
  end)
  it('aborts correctly', function()
    local _count = 0
    local _str = ''
    local add_job_expose = function(finish, count, str)
      _count = count + 1
      _str = str .. alphabet[count + 1]
      finish('success', nil, _count, _str)
    end
    local abort
    local abort_job = function()
      if abort then
        abort()
      end
    end

    abort = async_job.chain(add_job_expose, add_job_expose, abort_job, add_job_expose)(
      function() end,
      _count,
      _str
    )

    expect.equality(_count, 2)
    expect.equality(_str, 'AB')
  end)
end)
