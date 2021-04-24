local my_module = require('my_plugin.my_module')

describe("greeting", function()
   it('works!', function()
      assert.combinators.match("Hello Gabo", my_module.greeting("Gabo"))
   end)
end)

