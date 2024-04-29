local my_cool_module = require("grug-far.my_cool_module")

local M = {}

local function with_defaults(options)
  return {
    name = options.name or "John Doe"
  }
end

-- This function is supposed to be called explicitly by users to configure this
-- plugin
function M.setup(options)
  -- avoid setting global values outside of this function. Global state
  -- mutations are hard to debug and test, so having them in a single
  -- function/module makes it easier to reason about all possible changes
  M.options = with_defaults(options or {})

  -- do here any startup your plugin needs, like creating commands and
  -- mappings that depend on values passed in options
  vim.api.nvim_create_user_command("MyAwesomePluginGreet", M.greet, {})
end

function M.is_configured()
  return M.options ~= nil
end

-- This is a function that will be used outside this plugin code.
-- Think of it as a public API
function M.greet()
  if not M.is_configured() then
    return
  end

  -- try to keep all the heavy logic on pure functions/modules that do not
  -- depend on Neovim APIs. This makes them easy to test
  local greeting = my_cool_module.greeting(M.options.name)
  print(greeting)
end

-- Another function that belongs to the public API. This one does not depend on
-- user configuration
function M.generic_greet()
  print("Hello, unnamed friend!")
end

M.options = nil
return M
