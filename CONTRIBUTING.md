# Contributing

## Linting

You'll need to install [stylua][stylua] and [selene][selene].

```bash
$ make lint
```

## Testing

This uses [mini.test][mini.test]

To init the dependencies run

```bash
$ make prepare
```

To run all tests just execute

```bash
$ make test
```

## Github actions

An Action will run all the tests and lints on Pull Request to main. Tests will be run using 
[stable][neovim-test-versions] versions of Neovim (last 2).

[stylua]: https://github.com/JohnnyMorganz/StyLua
[selene]: https://kampfkarren.github.io/selene/cli/installation.html
[entr]: https://eradman.com/entrproject/
[luarocks]: https://luarocks.org/
[busted]: https://olivinelabs.com/busted/
[luassert]: https://github.com/Olivine-Labs/luassert
[plenary]: https://github.com/nvim-lua/plenary.nvim
[matcher_combinators]: https://github.com/m00qek/matcher_combinators.lua
[integration-badge]: https://github.com/m00qek/plugin-template.nvim/actions/workflows/integration.yml/badge.svg
[integration-runs]: https://github.com/m00qek/plugin-template.nvim/actions/workflows/integration.yml
[neovim-test-versions]: .github/workflows/integration.yml#L17
[mini.test]: https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-test.md
