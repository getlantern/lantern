package otto

import (
	. "./terst"
	"testing"
)

func Test_262(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`raise:
        eval("42 = 42;");
    `, "ReferenceError: Invalid left-hand side in assignment")
}

func Test_issue5(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`'abc' === 'def'`, "false")
	test(`'\t' === '\r'`, "false")
}
