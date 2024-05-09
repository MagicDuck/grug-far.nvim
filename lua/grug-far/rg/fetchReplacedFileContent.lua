local getArgs = require('grug-far/rg/getArgs')
local blacklistedReplaceFlags = require('grug-far/rg/blacklistedReplaceFlags')
local fetchWithRg = require('grug-far/rg/fetchWithRg')

local function fetchReplacedFileContent(params)
  local args = getArgs(params.inputs, params.options, {
    '--passthrough',
    '--no-line-number',
    '--no-column',
    '--color=never',
    '--no-heading',
    '--no-filename',
    params.file,
  }, blacklistedReplaceFlags)

  local content = ''
  return fetchWithRg({
    args = args,
    on_fetch_chunk = function(data)
      content = content .. data
    end,
    on_finish = function(status, errorMessage)
      params.on_finish(status, errorMessage, content)
    end
  })
end

return fetchReplacedFileContent
