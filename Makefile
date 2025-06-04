# Run tests
# use with update_screenshot=true to update the screenshots
# use with dir=... to test a particular dir under tests/
# use with file=... to test a particular file
# use with line=... to target a test at that line in the file 
# use with nvim_path=... to set a neovim executable to use when running the tests 

nvim_path ?= nvim

test:
	$(nvim_path) --headless --noplugin -u ./scripts/minimal_init.lua -l ./scripts/test_cli.lua

# launches test version of nvim that has the same plugin configuration as what the tests get
# this is useful sometiemes to check what is going on when child neovim processes just hang without any output
launch-test-nvim:
	$(nvim_path) --noplugin -u ./scripts/test_plugin_config.lua -c GrugFar

# clean / update all screenshots
update-screenshots:
	rm -rf tests/screenshots/* 
	make test

# Download 'mini.nvim' to use mini.test and mini.doc
deps/mini.nvim:
	@mkdir -p deps
	git clone --depth=1 --branch=v0.15.0 https://github.com/echasnovski/mini.nvim deps/mini.nvim

prepare: | deps/mini.nvim
	@mkdir -p temp_test_dir
	@mkdir -p temp_history_dir

clean:
	rm -rf deps
	rm -rf temp_test_dir
	rm -rf temp_history_dir

lint:
	selene lua tests
	stylua --check lua tests

documentation: | deps/mini.nvim
	$(nvim_path) --headless -i NONE --noplugin -u ./scripts/minidoc.lua -c "qa!"

docs-and-gitadd:
	make documentation
	git add doc
