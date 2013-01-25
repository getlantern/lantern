package otto

import (
	. "github.com/robertkrimen/terst"
	"testing"
)

func Test_issue5(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`'abc' === 'def'`, "false")
	test(`'\t' === '\r'`, "false")
}
