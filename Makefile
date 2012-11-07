.PHONY: test assets todo fixme otto run test-all release test-synopsis test-i test262

export TERST_BASE=$(PWD)

TEST := -v --run Otto 
TEST := -v --run underscore 
TEST := -v --run underscoreCollection
TEST := -v --run Speed
TEST := -v --run underscoreUtility
TEST := -v --run Array_slice
TEST := -v --run Date
TEST := -v .
TEST := -v --run Synopsis
TEST := -v --run _eval 
TEST := -v --run Broken
TEST := -v --run OttoError 
TEST := -v --run API
TEST := -v --run IsValidRegExp
TEST := -v --run SwitchBreak 
TEST := -v --run Unicode 
TEST := -v --run _issue
TEST := -v --run String_fromCharCode
TEST := -v --run Lexer\|Parse
TEST := -v --run Lexer
TEST := -v --run String_
TEST := -v --run ParseSuccess 
TEST := -v --run Parse
TEST := -v --run ParseFailure
TEST := -v --run RegExp 
TEST := -v --run stringToFloat 
TEST := -v --run TryFinally 
TEST := -v --run RegExp_exec
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
	cd otto && go build -a

run:
	go run -a ./otto/main.go ./otto.js

test-all: test-i
	go test .

release: test-all test-synopsis
	for package in . underscore registry; do (cd $$package && godocdown --signature > README.markdown); done

test-synopsis: test-i
	cd .test && go test -v
	cd .test && otto example.js

test262:
	$(MAKE) -C .test262 test
