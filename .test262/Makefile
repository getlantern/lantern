.PHONY: build test otto v8 cull uncull gauntlet try test-v8 test-otto tmp

otto := ./otto -underscore=false
TEST := python ./data/tools/packaging/test262.py --test=data --non_strict_only
WITH_v8 := --command v8
WITH_otto := --command "$(otto)"

test:
	$(TEST) $(WITH_otto)

test-otto: test

otto: build

build:
	$(MAKE) -C .. otto

data:
	hg clone -r 334 http://hg.ecmascript.org/tests/test262 data

v8 test-v8:
	$(TEST) $(WITH_v8)

test.v8:
	$(TEST) $(WITH_v8) > $@

cull: test.v8
	./cull

uncull:
	./uncull

gauntlet:
	-$(TEST) $(WITH_otto) 2>/dev/null | ./gauntlet
	@[ -f .fail ] && { cp .fail tmp; head .fail; }

try: .fail
	head $<
	cat shim.js $< | $(otto)
	@echo PASS

try-tmp: tmp
	cat shim.js $< | $(otto)
	@echo PASS

look: .fail
	cat $<
