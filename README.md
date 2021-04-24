plugin-template.nvim
===
[![Integration][integration-badge]][integration-runs]

A template to create Neovim plugins written in [Lua][lua]

## Using

Clone/download it locally and change the references to `my_plugin`, `my_module`
accordingly to your new plugin name.

You'll need to install [Lua][lua] and [LuaRocks][luarocks] to run the linter.

## Testing

This uses [busted][busted], [luassert][luassert] (both through
[plenary.nvim][plenary]) and [matcher_combinators][matcher_combinators] to 
define tests in `spec/` directory. These dependencies are required only to run
tests, that´s why they are installed as git submodules.
To run them just execute

```bash
$ make test
```

If you have [entr(1)][entr] installed you may use it to run all tests whenever a
file is changed using:

```bash
$ make watch
```

## Github actions

An Action will run all the tests and the linter on every commit on the main 
branch and also on Pull Request.


[lua]: https://www.lua.org/
[entr]: https://eradman.com/entrproject/
[luarocks]: https://luarocks.org/
[busted]: https://olivinelabs.com/busted/
[luassert]: https://github.com/Olivine-Labs/luassert
[plenary]: https://github.com/nvim-lua/plenary.nvim
[matcher_combinators]: https://github.com/m00qek/matcher_combinators.lua

[integration-badge]: https://github.com/m00qek/plugin-template.nvim/actions/workflows/integration.yml/badge.svg
[integration-runs]: https://github.com/m00qek/plugin-template.nvim/actions/workflows/integration.yml
