.PHONY: test build otto test-otto test-v8 release clean
.PHONY: cull uncull 
.PHONY: test.otto- test.v8- digest.json- report
.PHONY: release gauntlet try try-tmp look copy
.PHONY: panicking

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

test.otto:
	$(TEST) $(WITH_otto) | tee $@.tmp
	mv $@.tmp $@

test.otto-: 
	rm -f $(@:-=)
	$(MAKE) $(@:-=)

test-v8:
	$(TEST) $(WITH_v8)

test.v8:
	$(TEST) $(WITH_v8) | tee $@

test.v8-:
	$(MAKE) -B test.v8

release: otto gauntlet

clean:
	rm -f test.otto digest.json .node.tmp.js
	rm -rf test.*.tmp

digest.json: test.otto
	./digest < test.otto > $@

digest.json-:
	rm -f $(@:-=)
	$(MAKE) $(@:-=)

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

node-try-tmp: tmp.js
	cat shim.js $< > .node.tmp.js
	node ./.node.tmp.js

look: .fail
	cat $<
	@echo `readlink $<`

copy: .fail
	@echo `readlink $<` | pbcopy

panicking:
	rm -rf $@
	mkdir $@
	for panic in `$(MAKE) report | grep ^ch`; do \
		echo $$panic; \
		cp suite/$$panic.js $@; \
	done

