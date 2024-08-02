local fetchWithRg = require('grug-far/engine/ripgrep/fetchWithRg')
local parseResults = require('grug-far/engine/ripgrep/parseResults')
local fetchFilesWithMatches = require('grug-far/engine/ripgrep/fetchFilesWithMatches')
local replaceInMatchedFiles = require('grug-far/engine/ripgrep/replaceInMatchedFiles')
local getArgs = require('grug-far/engine/ripgrep/getArgs')
local colors = require('grug-far/engine/ripgrep/colors')

-- ripgrep engine API
---@type GrugFarEngine
local M = {
  type = 'ripgrep',

  search = function(params)
    local extraArgs = { '--color=ansi' }
    for k, v in pairs(colors.rg_colors) do
      table.insert(extraArgs, '--colors=' .. k .. ':none')
      table.insert(extraArgs, '--colors=' .. k .. ':fg:' .. v.rgb)
    end

    local args = getArgs(params.inputs, params.options, extraArgs)

    return fetchWithRg({
      args = args,
      options = params.options,
      on_fetch_chunk = function(data)
        params.on_fetch_chunk(parseResults(data))
      end,
      on_finish = params.on_finish,
    })
  end,

  replace = function(params)
    local report_progress = params.report_progress
    local on_finish = params.on_finish
    local on_abort = nil

    function abort()
      if on_abort then
        on_abort()
      end
    end

    on_abort = fetchFilesWithMatches({
      inputs = params.inputs,
      options = params.options,
      report_progress = function(count)
        report_progress('update_total', count)
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
          context = context,
          report_progress = function(count)
            report_progress('update_count', count)
          end,
          on_finish = on_finish,
        })
      end,
    })

    return abort

    ------------------
    -- local filesWithMatches = {}
    --
    -- local args, blacklistedArgs = getArgs(params.inputs, params.options, {
    --   '--files-with-matches',
    --   '--color=never',
    -- }, blacklistedReplaceFlags)
    --
    -- return fetchWithRg({
    --   args = args,
    --   options = params.options,
    --   on_fetch_chunk = function(data)
    --     local lines = vim.split(data, '\n')
    --     local count = 0
    --     for i = 1, #lines do
    --       if #lines[i] > 0 then
    --         table.insert(filesWithMatches, lines[i])
    --         count = count + 1
    --       end
    --     end
    --     reportProgress('update_total', count)
    --   end,
    --   on_finish = function(status, errorMessage)
    --     if not status then
    --       on_finish(
    --         nil,
    --         nil,
    --         blacklistedArgs
    --             and 'replace cannot work with flags: ' .. vim.fn.join(blacklistedArgs, ', ')
    --           or nil
    --       )
    --       return
    --     elseif status == 'error' then
    --       on_finish(status, errorMessage)
    --       return
    --     end
    --
    --     state.abort.replace = replaceInMatchedFiles({
    --       files = filesWithMatches,
    --       context = context,
    --       reportProgress = reportReplacedFilesUpdate,
    --       reportProgress = function() end,
    --       reportError = reportError,
    --       on_finish = on_finish,
    --     })
    --   end,
    -- })
  end,
}

return M
