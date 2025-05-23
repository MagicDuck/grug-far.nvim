local M = {}

---@class grug.far.FileIconsProvider
---@field type grug.far.FileIconsProviderType
---@field _lib? any
---@field get_lib fun():(lib: any)
---@field get_icon fun(lib: any, path: string):(icon:string, icon_hl: string)

---@type grug.far.FileIconsProvider[]
local providers = {
  {
    type = 'nvim-web-devicons',
    get_lib = function()
      local found, lib = pcall(require, 'nvim-web-devicons')
      if not found then
        return nil
      end

      -- check if setup() called
      if not lib.has_loaded() then
        return nil
      end

      return lib
    end,
    get_icon = function(self, path)
      -- first, try to match extensions like .spec.js
      local basename = vim.fs.basename(path)
      local multi_dot_extension = basename:match('[^.]*%.(.+)$')
      local icon, hl = self._lib.get_icon(path, multi_dot_extension, { default = false })
      if icon then
        return icon, hl
      end

      local extension = string.match(path, '.+%.(.+)$')
      return self._lib.get_icon(path, extension, { default = true })
    end,
  },
  {
    type = 'mini.icons',
    get_lib = function()
      local found, lib = pcall(require, 'mini.icons')
      if not found then
        return nil
      end
      -- according to mini.icons docs, need to check this
      -- to make sure setup has been called!
      -- selene: allow(global_usage)
      ---@diagnostic disable-next-line
      if not _G.MiniIcons then
        return nil
      end

      return lib
    end,
    get_icon = function(self, path)
      return self._lib.get('file', path)
    end,
  },
}

--- gets the icons provider
---@param type grug.far.FileIconsProviderType
function M.getProvider(type)
  if type == false then
    return nil
  end

  for _, provider in ipairs(providers) do
    local lib = provider.get_lib()

    if lib then
      if type == 'first_available' or provider.type == type then
        local new_provider = vim.deepcopy(provider)
        new_provider._lib = lib
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
