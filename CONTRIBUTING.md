# Contributing

## Pre-Commit

Install pre-commit as per https://pre-commit.com (might be possible through your package manager)
Run :
```bash
$ pre-commit install
```

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
Please follow instructions to get right version of dependencies such as ripgrep and astgrep.

To run specific test:
```bash
$ make test dir=base file=test_search.lua
```

To run test at specific line:
```bash
$ make test dir=base file=test_search.lua line=83
```
To update screenshots:
```bash
$ make test dir=base file=test_search.lua update_screenshots=true
```

## Github actions

An Action will run all the tests and lints on Pull Request to main. Tests will be run using 
a [stable][neovim-test-versions] version of Neovim.

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
