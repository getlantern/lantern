package otto

import (
    "testing"
    . "github.com/robertkrimen/terst"
)

func Test_issue5(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`'abc' === 'def'`, "false")
	test(`'\t' === '\r'`, "false")
}
