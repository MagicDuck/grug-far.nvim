---@type GrugFarReplacementInterpreter
local LuaInterpreter = {
  type = 'lua',

  get_eval_fn = function(script)
    local chunkheader = 'local match = ...;\n'
    local _, chunk, error = pcall(loadstring, chunkheader .. script, 'luaeval')
    if chunk then
      return function(...)
        return tostring(chunk(...))
      end
    else
      return nil, error or 'could not evaluate lua chunk'
    end
  end,
}

return LuaInterpreter
