# Run all test files
test:
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

# Run test from file at `$FILE` environment variable, ex: make test-file FILE=...
test-file:
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

update-screenshots:
	rm -rf tests/screenshots/* 
	make test

# Download 'mini.nvim' to use its 'mini.test' testing module
prepare:
	make clean
	@mkdir -p deps
	git clone --depth=1 --single-branch https://github.com/echasnovski/mini.nvim deps/mini.nvim
	@mkdir -p temp_test_dir
# clean up
clean:
	rm -rf deps
	rm -rf temp_test_dir
# lint
lint:
	selene lua tests
	stylua --check lua tests
