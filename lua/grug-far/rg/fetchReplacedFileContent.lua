local getArgs = require('grug-far/rg/getArgs')
local fetchWithRg = require('grug-far/rg/fetchWithRg')

local function fetchReplacedFileContent(params)
  local args = getArgs(params.inputs, params.options)
  if args then
    table.insert(args, '--passthrough')
    table.insert(args, '--no-line-number')
    table.insert(args, '--no-column')
    table.insert(args, '--color=never')
    table.insert(args, '--no-heading')
    table.insert(args, '--no-filename')

    table.insert(args, params.file)
  end

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
