let s:my_awesome_plugin = luaeval('require("my_awesome_plugin")')

if s:my_awesome_plugin.is_configured()
  " Neovim does not expose a lua API to create commands yet
  command! MyPluginGreet call s:my_awesome_plugin.greet()
endif
