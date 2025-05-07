---@type string?
local sg_version = nil

--- gets the ast-grep version in use.
---Only first call does an actual check rest are from cache
---@param options grug.far.Options
---@return string? version
local function getAstgrepVersion(options)
  if not sg_version then
    local handle = io.popen(options.engines.astgrep.path .. ' --version')
    if handle then
      sg_version = handle:read('*a')
      local eol = sg_version:find('\n')
      if eol then
        sg_version = sg_version:sub(1, eol - 1)
      end
      sg_version = string.gsub(sg_version, 'ast-grep', '')
      sg_version = string.gsub(sg_version, '[%s]*', '')
      handle:close()
    end
    if not sg_version or #sg_version == 0 then
      sg_version = nil
    end
  end

  return sg_version
end

return getAstgrepVersion
