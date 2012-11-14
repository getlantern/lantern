.PHONY: build test otto v8 cull uncull gauntlet try test-v8 test-otto copy test.otto clean

otto := ./otto -underscore=false
TEST := python ./data/tools/packaging/test262.py --test=data --non_strict_only
WITH_v8 := --command v8
WITH_otto := --command "$(otto)"

test:
	$(TEST) $(WITH_otto)

digest.json:
	./digest < test.otto > $@

release: otto gauntlet

test-otto: test

otto: build

build:
	$(MAKE) -C .. otto

data:
	hg clone -r 334 http://hg.ecmascript.org/tests/test262 data

test.otto: otto
	$(TEST) $(WITH_otto) | tee $@

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
	@[ -f .fail ] && { cp .fail tmp.js; head .fail; }

try: .fail
	head $<
	cat shim.js $< | $(otto)
	@echo PASS

try-tmp: tmp.js
	cat shim.js $< | $(otto)
	@echo PASS

look: .fail
	cat $<
	@echo `readlink $<`

copy: .fail
	@echo `readlink $<` | pbcopy

clean:
	rm -f test.otto digest.json
