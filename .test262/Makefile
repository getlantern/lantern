.PHONY: build test data otto v8 cull uncull

TEST := python ./data/tools/packaging/test262.py --test=data --non_strict_only
WITH_v8 := --command v8
WITH_otto := --command "./otto -underscore=false"

test:
	$(TEST) $(WITH_otto)

otto: test

build:
	$(MAKE) -C .. otto

data:
	hg clone -r 334 http://hg.ecmascript.org/tests/test262 data

v8:
	$(TEST) $(WITH_v8)

test.v8:
	$(TEST) $(WITH_v8) > $@

cull: test.v8
	./cull

uncull:
	./uncull
