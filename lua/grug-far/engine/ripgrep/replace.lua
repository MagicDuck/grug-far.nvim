local fetchFilesWithMatches = require('grug-far.engine.ripgrep.fetchFilesWithMatches')
local fetchCommandOutput = require('grug-far.engine.fetchCommandOutput')
local replaceInMatchedFiles = require('grug-far.engine.ripgrep.replaceInMatchedFiles')
local getArgs = require('grug-far.engine.ripgrep.getArgs')
local argUtils = require('grug-far.engine.ripgrep.argUtils')
local parseResults = require('grug-far.engine.ripgrep.parseResults')
local utils = require('grug-far.utils')
local async_job = require('grug-far.async_job')
local uv = vim.uv

local M = {}

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

--- replaces in bufrange
---@param params {
--- inputs: grug.far.Inputs,
--- options: grug.far.Options,
--- replacement_eval_fn?: fun(...): (string?, string?),
--- bufrange: grug.far.VisualSelectionInfo,
--- report_progress: fun(count: integer),
--- on_finish: fun(status: grug.far.Status, errorMessage: string?),
--- }
local function replaceInBufrange(params)
  local on_finish = params.on_finish
  local replacement_eval_fn = params.replacement_eval_fn
  local bufrange = params.bufrange

  local inputs = vim.deepcopy(params.inputs)
  inputs.paths = ''
  local args
  if replacement_eval_fn then
    args = getArgs(inputs, params.options, { '--json' })
    args = argUtils.stripReplaceArgs(args)
  else
    args = getArgs(inputs, params.options, {
      '--passthrough',
      '--no-line-number',
      '--no-column',
      '--color=never',
      '--no-heading',
      '--no-filename',
    })
  end

  local json_data = {}
  local text_data = ''
  local chunk_error = nil
  local abort
  local stdin = uv.new_pipe()
  local input_text = table.concat(bufrange.lines, utils.eol)
  abort = fetchCommandOutput({
    cmd_path = params.options.engines.ripgrep.path,
    args = args,
    stdin = stdin,
    on_fetch_chunk = function(data)
      if chunk_error then
        return
      end

      if replacement_eval_fn then
        local json_list = utils.str_to_json_list(data)
        for _, entry in ipairs(json_list) do
          if entry.type == 'match' then
            for _, submatch in ipairs(entry.data.submatches) do
              local replacementText, err = replacement_eval_fn(submatch.match.text)
              if err then
                chunk_error = err
                if abort then
                  abort()
                end
                return
              end
              submatch.replacement = { text = replacementText }
            end
          end
          table.insert(json_data, entry)
        end
      else
        text_data = text_data .. data
      end
    end,
    on_finish = function(status, errorMessage)
      if status == 'error' then
        return on_finish('error', errorMessage)
      end

      if chunk_error then
        return on_finish(chunk_error)
      end

      if status == 'success' and (#json_data > 0 or #text_data > 0) then
        local new_text = replacement_eval_fn
            and parseResults.getReplacedContents(input_text, json_data)
          or text_data:sub(1, -2) -- strip of extra \n introduced by rg

        utils.writeInBufrange(bufrange, vim.split(new_text, utils.eol))
      end

      return on_finish('success')
    end,
  })

  ---@cast stdin -uv.uv_pipe_t
  ---@cast stdin -?
  ---@cast stdin +uv.uv_stream_t
  uv.write(stdin, input_text, function()
    uv.shutdown(stdin)
  end)

  return abort
end

--- does replace
---@param params grug.far.EngineReplaceParams
---@return fun()? abort
M.replace = function(params)
  local report_progress = params.report_progress
  local on_finish = params.on_finish

  local args = getArgs(params.inputs, params.options, {})
  if not args then
    on_finish(nil, nil, 'replace cannot work with the current arguments!')
    return
  end

  if not params.replacementInterpreter and isEmptyStringReplace(args) then
    local choice = vim.fn.confirm('Replace matches with empty string?', '&yes\n&cancel')
    if choice ~= 1 then
      on_finish(nil, nil, 'replace with empty string canceled!')
      return
    end
  end

  local replacement_eval_fn
  if params.replacementInterpreter then
    local interpreterError
    replacement_eval_fn, interpreterError =
      params.replacementInterpreter.get_eval_fn(params.inputs.replacement, { 'match' })
    if not replacement_eval_fn then
      params.on_finish('error', interpreterError)
      return
    end
  end

  local bufrange, bufrange_err = utils.getBufrange(params.inputs.paths)
  if bufrange_err then
    params.on_finish('error', bufrange_err)
    return
  end

  local hooks = params.options.hooks

  if bufrange then
    return async_job.chain(function(finish)
      if hooks.on_before_edit_file then
        report_progress({ type = 'message', message = 'running on before edit file hook' })
        hooks.on_before_edit_file(finish, {
          path = bufrange.file_name,
          isBufferRange = true,
        })
      else
        finish('success')
      end
    end, function(finish)
      return replaceInBufrange({
        inputs = params.inputs,
        options = params.options,
        bufrange = bufrange,
        replacement_eval_fn = replacement_eval_fn,
        report_progress = function(count)
          report_progress({ type = 'update_count', count = count })
        end,
        on_finish = finish,
      })
    end)(on_finish)
  else
    return async_job.chain(function(finish)
      return fetchFilesWithMatches({
        inputs = params.inputs,
        options = params.options,
        report_progress = function(count)
          report_progress({ type = 'update_total', count = count })
        end,
        on_finish = finish,
      })
    end, function(finish, files)
      if hooks.on_before_edit_file then
        report_progress({ type = 'message', message = 'running on before edit file hook' })

        return async_job.parallel_process({
          items = vim
            .iter(files)
            :map(function(file)
              return { path = file }
            end)
            :totable(),
          maxWorkers = params.options.maxWorkers,
          process_item = hooks.on_before_edit_file,
          on_finish = function(status, errorMessage)
            finish(status, errorMessage, files)
          end,
        })
      else
        finish('success', nil, files)
        return
      end
    end, function(finish, files)
      return replaceInMatchedFiles({
        files = files,
        inputs = params.inputs,
        options = params.options,
        replacement_eval_fn = replacement_eval_fn,
        report_progress = function(count)
          report_progress({ type = 'update_count', count = count })
        end,
        on_finish = finish,
      })
    end)(on_finish)
  end
end

return M
