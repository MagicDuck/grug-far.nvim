local fetchCommandOutput = require('grug-far/engine/fetchCommandOutput')
local getArgs = require('grug-far/engine/astgrep/getArgs')
local blacklistedReplaceFlags = require('grug-far/engine/astgrep/blacklistedReplaceFlags')
local fetchFilteredFilesList = require('grug-far/engine/ripgrep/fetchFilteredFilesList')
local runWithChunkedFiles = require('grug-far/engine/runWithChunkedFiles')

local M = {}

--- does replace
---@param params EngineReplaceParams
---@return fun()? abort, string[]? effectiveArgs
function M.replace(params)
  local report_progress = params.report_progress
  local on_finish = params.on_finish

  local extraArgs = {
    '--update-all',
  }
  local args, blacklistedArgs =
    getArgs(params.inputs, params.options, extraArgs, blacklistedReplaceFlags, true)

  if blacklistedArgs and #blacklistedArgs > 0 then
    on_finish(nil, nil, 'replace cannot work with flags: ' .. vim.fn.join(blacklistedArgs, ', '))
    return
  end

  if not args then
    on_finish(nil, nil, 'replace cannot work with the current arguments!')
    return
  end

  if #params.inputs.replacement == 0 then
    local choice = vim.fn.confirm('Replace matches with empty string?', '&yes\n&cancel')
    if choice ~= 1 then
      on_finish(nil, nil, 'replace with empty string canceled!')
      return
    end
  end

  local on_abort = nil
  local function abort()
    if on_abort then
      on_abort()
    end
  end

  report_progress({
    type = 'message',
    message = 'replacing... (buffer temporarily not modifiable)',
  })

  local filesFilter = params.inputs.filesFilter
  if filesFilter and #filesFilter > 0 then
    -- ast-grep currently does not support --glob type functionality
    -- see see https://github.com/ast-grep/ast-grep/issues/1062
    -- this if-branch uses rg to get the files and can be removed if that is implemented
    on_abort = fetchFilteredFilesList({
      inputs = params.inputs,
      options = params.options,
      report_progress = function() end,
      on_finish = function(status, errorMessage, files)
        if not status then
          on_finish(nil, nil, nil)
          return
        elseif status == 'error' then
          on_finish(status, errorMessage)
          return
        end

        on_abort = runWithChunkedFiles({
          files = files,
          chunk_size = 200,
          options = params.options,
          run_chunk = function(chunk, on_done)
            local chunk_args = vim.deepcopy(args)
            for _, file in ipairs(vim.split(chunk, '\n')) do
              table.insert(chunk_args, file)
            end

            return fetchCommandOutput({
              cmd_path = params.options.engines.astgrep.path,
              args = chunk_args,
              on_fetch_chunk = function()
                -- astgrep does not report progess while replacing
              end,
              on_finish = function(_, _errorMessage)
                return on_done((_errorMessage and #_errorMessage > 0) and _errorMessage or nil)
              end,
            })
          end,
          on_finish = on_finish,
        })
      end,
    })
  else
    on_abort = fetchCommandOutput({
      cmd_path = params.options.engines.astgrep.path,
      args = args,
      on_fetch_chunk = function()
        -- astgrep does not report progess while replacing
      end,
      on_finish = on_finish,
    })
  end

  return abort
end

return M
