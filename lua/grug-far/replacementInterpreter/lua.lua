---@type GrugFarReplacementInterpreter
local LuaInterpreter = {
  type = 'lua',

  get_eval_fn = function(script, arg_names)
    local chunkheader = 'local ' .. vim.fn.join(arg_names, ', ') .. ' = ...;\n'
    local _, chunk, error = pcall(loadstring, chunkheader .. script, 'Replace')
    if chunk then
      return function(...)
        local result = chunk(...)
        return result and tostring(result) or ''
      end
    else
      return nil, error or 'could not evaluate lua chunk'
    end
  end,
}

return LuaInterpreter
