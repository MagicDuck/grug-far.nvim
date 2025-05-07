---@type string?
local rg_version = nil

--- gets the rg version in use.
---Only first call does an actual check rest are from cache
---@param options grug.far.Options
---@return string? version
local function getRgVersion(options)
  if not rg_version then
    local handle = io.popen(options.engines.ripgrep.path .. ' --version')
    if handle then
      rg_version = handle:read('*a')
      local eol = rg_version:find('\n')
      if eol then
        rg_version = rg_version:sub(1, eol - 1)
      end
      rg_version = string.gsub(rg_version, 'ripgrep', '')
      rg_version = string.gsub(rg_version, '[%s]*', '')
      handle:close()
    end
    if not rg_version or #rg_version == 0 then
      rg_version = nil
    end
  end

  return rg_version
end

return getRgVersion
