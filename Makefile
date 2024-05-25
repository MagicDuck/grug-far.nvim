# Run tests
# use with update_screenshot=true to update the screenshots
# use with file=... to test a particular file
# use with line=... to target a test at that line in the file 
test:
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -l ./scripts/test_cli.lua

update-screenshots:
	rm -rf tests/screenshots/* 
	make test

# Download 'mini.nvim' to use its 'mini.test' testing module
prepare:
	make clean
	@mkdir -p deps
	git clone --depth=1 --single-branch https://github.com/echasnovski/mini.nvim deps/mini.nvim
	@mkdir -p temp_test_dir
	@mkdir -p temp_history_dir
# clean up
clean:
	rm -rf deps
	rm -rf temp_test_dir
	rm -rf temp_history_dir
# lint
lint:
	selene lua tests
	stylua --check lua tests
