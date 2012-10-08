.PHONY: test assets todo fixme otto run test-all README

export TERST_BASE=$(PWD)

TEST := -v --run RegExp 
TEST := -v --run Otto 
TEST := -v --run underscore 
TEST := -v --run underscoreCollection
TEST := -v --run Speed
TEST := -v --run underscoreUtility
TEST := -v --run Array_slice
TEST := -v --run Date
TEST := -v .
TEST := -v --run Lexer
TEST := -v --run Synopsis
TEST := -v --run ParseFailure
TEST := -v --run _eval 
TEST := -v --run Broken
TEST := -v --run ParseSuccess 
TEST := .

test:
	go test $(TEST)

assets:
	mkdir -p .assets
	for file in underscore/test/*.js; do tr "\`" "_" < $$file > .assets/`basename $$file`; done

todo:
	ack -l TODO *.go

fixme:
	ack -l FIXME *.go

otto:
	cd otto && go build

run:
	go run -a ./otto/main.go ./otto.js

test-all:
	go test .

README:
	godoc . | godocdown > README.md
