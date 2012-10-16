.PHONY: build test data otto v8 

test:
	python ./data/tools/packaging/test262.py --command "./otto -underscore=false" --test=data --non_strict_only

otto: test

build:
	$(MAKE) -C .. otto

data:
	hg clone -r 334 http://hg.ecmascript.org/tests/test262 data

v8:
	python ./data/tools/packaging/test262.py --command v8 --test=data --non_strict_only
