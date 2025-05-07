---@type grug.far.ReplacementInterpreter
local LuaInterpreter = {
  type = 'lua',

  language = 'lua',

  get_eval_fn = function(script, arg_names)
    local chunkheader = 'local ' .. table.concat(arg_names, ', ') .. ' = ...; '
    local _, replace, error = pcall(loadstring, chunkheader .. script, 'Replace')
    if replace then
      return function(...)
        local success, result = pcall(replace, ...)
        if success then
          return result and tostring(result) or '', nil
        else
          return nil, result
        end
      end
    else
      return nil, 'Replace [lua]\n' .. (error or 'could not evaluate lua chunk')
    end
  end,
}

return LuaInterpreter
