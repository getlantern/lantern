.PHONY: test assets todo fixme otto run test-all release test-synopsis test-i test262 check
.PHONY: underscore

TEST := -v --run
TEST := .

test: test-i
	go test $(TEST)

test-i:
	go test -i

assets:
	mkdir -p .assets
	for file in underscore/test/*.js; do tr "\`" "_" < $$file > .assets/`basename $$file`; done

todo:
	ack -l TODO *.go

fixme:
	ack -l FIXME *.go

otto:
	$(MAKE) -C otto

run:
	go run -a ./otto/main.go ./otto.js

test-all: test-i
	go test .

release: check test-all test-synopsis
	for package in . underscore registry; do (cd $$package && godocdown --signature > README.markdown); done

check:
	GOROOT= $(HOME)/go/release/bin/go test -a .

test-synopsis: .test test-i otto
	$(MAKE) -C .test/synopsis

test262: .test
	$(MAKE) -C .test/test262 test

underscore:
	$(MAKE) -C $@
