local my_cool_module = require("my_awesome_plugin.my_cool_module")

local my_awesome_plugin = {}

local function with_defaults(options)
   return {
      name = options.name or "John Doe"
   }
end

function my_awesome_plugin.setup(options)
   -- avoid setting global values outside of this function. Global state
   -- mutations are hard to debug and test, so having them in a single
   -- function/moduler makes it easier to reason about all possible changes
   my_awesome_plugin.options = with_defaults(options)

   -- do here any startup your plugin needs

   -- this is also a good place for creating mappings
end

function my_awesome_plugin.is_configured()
   return my_awesome_plugin.options ~= nil
end

-- this is some function that will be used outside this plugin code. Think of it
-- as a public API
function my_awesome_plugin.greet()
   if not my_awesome_plugin.is_configured() then
      return
   end

   -- try to keep all the heavy logic on pure functions/modules that does not
   -- depend on neovim APIs because this makes them easy to test
   local greeting = my_cool_module.greeting(my_awesome_plugin.options.name)
   vim.api.nvim_echo({ { greeting } }, false, {})
end

my_awesome_plugin.options = nil
return my_awesome_plugin
