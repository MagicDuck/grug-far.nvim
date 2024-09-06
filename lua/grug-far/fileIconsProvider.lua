local M = {}

---@class FileIconsProvider
---@field type FileIconsProviderType
---@field _inst? any
---@field get_inst fun():(inst: any)
---@field get_icon fun(inst: any, path: string):(icon:string, icon_hl: string)

---@type FileIconsProvider[]
local providers = {
  {
    type = 'mini.icons',
    get_inst = function()
      local _, inst = pcall(require, 'mini.icons')
      if not inst then
        return nil
      end
      -- according to mini.icons docs, need to check this
      -- to make sure setup has been called!
      if not _G.MiniIcons then
        return nil
      end

      return inst
    end,
    get_icon = function(self, path)
      return self._inst.get('file', path)
    end,
  },
  {
    type = 'nvim-web-devicons',
    get_inst = function()
      local _, inst = pcall(require, 'nvim-web-devicons')
      if not inst then
        return nil
      end

      -- check if setup() called
      if not inst.has_loaded() then
        return nil
      end

      return inst
    end,
    get_icon = function(self, path)
      local extension = string.match(path, '.+%.(.+)$')
      return self._inst.get_icon(path, extension, { default = true })
    end,
  },
}

--- gets the icons provider
---@param type FileIconsProviderType
function M.getProvider(type)
  if type == false then
    return nil
  end

  for _, provider in ipairs(providers) do
    local inst = provider.get_inst()

    if inst then
      if type == 'first_available' or provider.type == type then
        local new_provider = vim.deepcopy(provider)
        new_provider._inst = inst
        return new_provider
      end
    else
      if provider.type == type then
        return nil
      end
    end
  end

  return nil
end

return M
