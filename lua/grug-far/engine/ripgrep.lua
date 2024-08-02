local fetchCommandOutput = require('grug-far/engine/fetchCommandOutput')
local parseResults = require('grug-far/engine/ripgrep/parseResults')
local fetchFilesWithMatches = require('grug-far/engine/ripgrep/fetchFilesWithMatches')
local replaceInMatchedFiles = require('grug-far/engine/ripgrep/replaceInMatchedFiles')
local getArgs = require('grug-far/engine/ripgrep/getArgs')
local colors = require('grug-far/engine/ripgrep/colors')

--- are we replacing matches with the empty string?
---@param args string[]
---@return boolean
local function isEmptyStringReplace(args)
  local replaceEqArg = '--replace='
  for i = #args, 1, -1 do
    local arg = args[i]
    if vim.startswith(arg, replaceEqArg) then
      if #arg > #replaceEqArg then
        return false
      else
        return true
      end
    end
  end

  return true
end

---@type GrugFarEngine
local RipgrepEngine = {
  type = 'ripgrep',

  search = function(params)
    local extraArgs = { '--color=ansi' }
    for k, v in pairs(colors.rg_colors) do
      table.insert(extraArgs, '--colors=' .. k .. ':none')
      table.insert(extraArgs, '--colors=' .. k .. ':fg:' .. v.rgb)
    end

    local args = getArgs(params.inputs, params.options, extraArgs)

    return fetchCommandOutput({
      cmd_path = params.options.rgPath,
      args = args,
      options = params.options,
      on_fetch_chunk = function(data)
        params.on_fetch_chunk(parseResults(data))
      end,
      on_finish = function(status, errorMessage)
        if status == 'error' and errorMessage and #errorMessage == 0 then
          errorMessage = 'no matches'
        end
        params.on_finish(status, errorMessage)
      end,
    })
  end,

  replace = function(params)
    local report_progress = params.report_progress
    local on_finish = params.on_finish

    local args = getArgs(params.inputs, params.options, {})
    if not args then
      on_finish(nil, nil, 'replace cannot work with the current arguments!')
      return
    end

    if isEmptyStringReplace(args) then
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

    on_abort = fetchFilesWithMatches({
      inputs = params.inputs,
      options = params.options,
      report_progress = function(count)
        report_progress({ type = 'update_total', count = count })
      end,
      on_finish = function(status, errorMessage, files, blacklistedArgs)
        if not status then
          on_finish(
            nil,
            nil,
            blacklistedArgs
                and 'replace cannot work with flags: ' .. vim.fn.join(blacklistedArgs, ', ')
              or nil
          )
          return
        elseif status == 'error' then
          on_finish(status, errorMessage)
          return
        end

        on_abort = replaceInMatchedFiles({
          files = files,
          inputs = params.inputs,
          options = params.options,
          report_progress = function(count)
            report_progress({ type = 'update_count', count = count })
          end,
          on_finish = on_finish,
        })
      end,
    })

    return abort
  end,
}

return RipgrepEngine
