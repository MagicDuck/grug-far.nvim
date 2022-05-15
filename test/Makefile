SPEC=

RUN=nvim --headless --noplugin -u spec.vim

prepare:
	@git submodule update --depth 1 --init

nvim:
	@nvim --noplugin -u spec.vim

test: prepare
ifeq ($(strip $(SPEC)),) # a.k.a. $(SPEC) is empty
	@$(RUN) -c "PlenaryBustedDirectory spec/ { minimal_init = 'spec.vim' }"
else
	@$(RUN) -c "PlenaryBustedFile $(SPEC)"
endif

watch: prepare
	@echo -e '\nRunning tests on "spec/**/*_spec.lua" when any Lua file on "../lua/" and "spec/" changes\n'
	@find spec/ ../lua/ -name '*.lua' \
	  | entr make test SPEC=$(SPEC)
