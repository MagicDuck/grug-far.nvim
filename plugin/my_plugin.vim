let s:my_plugin = luaeval('require("my_plugin")')

if s:my_plugin.is_configured()
  " Neovim does not expose a lua API to create commands yet
  command! MyPluginGreet call s:my_plugin.greet()
endif
