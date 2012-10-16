.PHONY: build test data

test:
	python ./data/tools/packaging/test262.py --command "./otto -underscore=false" --test=data --non_strict_only

build:
	$(MAKE) -C .. otto

data:
	hg clone -r 334 http://hg.ecmascript.org/tests/test262 data
