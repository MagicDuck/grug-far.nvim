---@type GrugFarReplacementInterpreter
local LuaInterpreter = {
  type = 'lua',

  eval = function(script, params)
    local param_names = {}
    local param_values = {}
    for arg_name, arg_value in pairs(params) do
      table.insert(param_names, arg_name)
      table.insert(param_values, arg_value)
    end

    local chunkheader = 'local ' .. vim.fn.join(param_names, ', ') .. ' = ...;\n'
    local _, chunk, error = pcall(loadstring, chunkheader .. script, 'luaeval')
    if chunk then
      return tostring(chunk(unpack(param_values)))
    else
      return nil, error or 'could not evaluate lua chunk'
    end
  end,
}

return LuaInterpreter
