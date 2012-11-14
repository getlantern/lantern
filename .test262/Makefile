.PHONY: test build otto test-otto test-v8 release clean
.PHONY: cull uncull 
.PHONY: test.otto- test.v8- digest.json- report
.PHONY: release gauntlet try try-tmp look copy

otto := ./otto -underscore=false
TEST := python ./data/tools/packaging/test262.py --test=data --non_strict_only
WITH_v8 := --command v8
WITH_otto := --command "$(otto)"

test: test-otto

build:
	$(MAKE) -C .. otto

otto: build

test-otto:
	$(TEST) $(WITH_otto)

test.otto: otto
	$(TEST) $(WITH_otto) | tee $@

test.otto-: 
	$(MAKE) -B test.otto

test-v8:
	$(TEST) $(WITH_v8)

test.v8:
	$(TEST) $(WITH_v8) | tee $@

test.v8-:
	$(MAKE) -B test.v8

release: otto gauntlet

clean:
	rm -f test.otto digest.json

digest.json:
	./digest < test.otto > $@

digest.json-:
	$(MAKE) -B digest.json

report: digest.json
	@./report < digest.json

data:
	hg clone -r 334 http://hg.ecmascript.org/tests/test262 data

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
