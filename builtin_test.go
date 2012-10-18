package otto

import (
    "testing"
    . "github.com/robertkrimen/terst"
)

func TestString_fromCharCode(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`String.fromCharCode()`, "")
	test(`String.fromCharCode(88, 121, 122, 122, 121)`, "Xyzzy")
	test(`String.fromCharCode("88", 121, 122, 122.05, 121)`, "Xyzzy")
	test(`String.fromCharCode("88", 121, 122, NaN, 121)`, "Xyz\x00y")
	test(`String.fromCharCode("0x21")`, "!")
}

