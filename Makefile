.PHONY: assets todo fixme otto run test-all release test-synopsis test262
.PHONY: test test-race test-check test-all
.PHONY: underscore

TESTS := \
	~

TEST := -v --run
TEST := -v --run Test\($(subst $(eval) ,\|,$(TESTS))\)
TEST := .

CHECK_GO := GOROOT= GOPATH=$(PWD)/.test/check/:$(GOPATH) $(HOME)/go/release/bin/go
CHECK_OTTO := $(PWD)/.test/check/src/github.com/robertkrimen/otto

test: inline.go
	go test -i
	go test $(TEST)

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

test-all: inline.go
	go test -i
	go test

release: test-race test-all test-synopsis
	for package in . underscore registry; do (cd $$package && godocdown --signature > README.markdown); done

test-race:
	go test -race -i
	go test -race

test-check:
	@mkdir -p $(CHECK_OTTO)
	@find . -name \*.go ! -path ./.\* -maxdepth 2 | rsync -a --files-from -  ./ $(CHECK_OTTO)/
	$(CHECK_GO) version
	$(CHECK_GO) test -i
	$(CHECK_GO) test

test-synopsis: .test otto
	$(MAKE) -C .test/synopsis 1>/dev/null

test262: .test
	$(MAKE) -C .test/test262 test

underscore:
	$(MAKE) -C $@

inline.go: inline
	./$< > $@

