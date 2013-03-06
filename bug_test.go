package otto

import (
	. "github.com/robertkrimen/terst"
	"testing"
)

func Test_262(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`raise:
        42 = 42;
    `, "ReferenceError: Invalid left-hand side in assignment")
}

func Test_issue5(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`'abc' === 'def'`, "false")
	test(`'\t' === '\r'`, "false")
}
