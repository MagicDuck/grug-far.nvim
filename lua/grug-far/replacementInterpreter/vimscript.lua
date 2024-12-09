---@type GrugFarReplacementInterpreter
local VimscriptInterpreter = {
  type = 'vimscript',

  language = 'vim',

  get_eval_fn = function(script, arg_names)
    local exec_success, exec_error = pcall(
      vim.api.nvim_exec2,
      'function! __grug_far_vimscript_eval('
        .. table.concat(arg_names, ', ')
        .. ')\n'
        .. table.concat(
          vim
            .iter(arg_names)
            :map(function(arg_name)
              return 'let ' .. arg_name .. ' = a:' .. arg_name .. ' | '
            end)
            :totable(),
          ''
        )
        .. script
        .. '\nendfunction',
      {}
    )
    if exec_success then
      return function(...)
        local success, result = pcall(vim.fn.__grug_far_vimscript_eval, ...)
        if success then
          return result and tostring(result) or '', nil
        else
          return nil,
            'Replace [vimscript]:\n' .. result:gsub('function __grug_far_vimscript_eval, ', '')
        end
      end
    else
      return nil, 'Replace [vimscript]:\n' .. (exec_error or 'could not evaluate vimscript chunk')
    end
  end,
}

return VimscriptInterpreter
