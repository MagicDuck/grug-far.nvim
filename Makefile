# Run all test files
test: deps/mini.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

# Run test from file at `$FILE` environment variable, ex: make test-file FILE=...
test-file: deps/mini.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

# Download 'mini.nvim' to use its 'mini.test' testing module
prepare:
	@mkdir -p deps
	# git clone --filter=blob:none https://github.com/echasnovski/mini.nvim deps/mini.nvim
	git clone --depth=1 --single-branch https://github.com/echasnovski/mini.nvim deps/mini.nvim
# clean up
clean:
	rm -rf deps
# lint
lint:
	selene lua tests
	stylua --check lua tests
