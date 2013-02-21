package otto

import (
	. "github.com/robertkrimen/terst"
	"testing"
)

func TestString_fromCharCode(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`String.fromCharCode()`, "")
	test(`String.fromCharCode(88, 121, 122, 122, 121)`, "Xyzzy")
	test(`String.fromCharCode("88", 121, 122, 122.05, 121)`, "Xyzzy")
	test(`String.fromCharCode("88", 121, 122, NaN, 121)`, "Xyz\x00y")
	test(`String.fromCharCode("0x21")`, "!")
	test(`String.fromCharCode(-1).charCodeAt(0)`, "65535")
	test(`String.fromCharCode(65535).charCodeAt(0)`, "65535")
	test(`String.fromCharCode(65534).charCodeAt(0)`, "65534")
	test(`String.fromCharCode(4294967295).charCodeAt(0)`, "65535")
	test(`String.fromCharCode(4294967294).charCodeAt(0)`, "65534")
}

func TestString_substr(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`"abc".substr(0,1)`, "a")
	test(`"abc".substr(0,2)`, "ab")
	test(`"abc".substr(0,3)`, "abc")
	test(`"abc".substr(0,4)`, "abc")
	test(`"abc".substr(0,9)`, "abc")

	test(`"abc".substr(1,1)`, "b")
	test(`"abc".substr(1,2)`, "bc")
	test(`"abc".substr(1,3)`, "bc")
	test(`"abc".substr(1,4)`, "bc")
	test(`"abc".substr(1,9)`, "bc")

	test(`"abc".substr(2,1)`, "c")
	test(`"abc".substr(2,2)`, "c")
	test(`"abc".substr(2,3)`, "c")
	test(`"abc".substr(2,4)`, "c")
	test(`"abc".substr(2,9)`, "c")

	test(`"abc".substr(3,1)`, "")
	test(`"abc".substr(3,2)`, "")
	test(`"abc".substr(3,3)`, "")
	test(`"abc".substr(3,4)`, "")
	test(`"abc".substr(3,9)`, "")

	test(`"abc".substr(0)`, "abc")
	test(`"abc".substr(1)`, "bc")
	test(`"abc".substr(2)`, "c")
	test(`"abc".substr(3)`, "")
	test(`"abc".substr(9)`, "")

	test(`"abc".substr(-9)`, "abc")
	test(`"abc".substr(-3)`, "abc")
	test(`"abc".substr(-2)`, "bc")
	test(`"abc".substr(-1)`, "c")

	test(`"abc".substr(-9, 1)`, "a")
	test(`"abc".substr(-3, 1)`, "a")
	test(`"abc".substr(-2, 1)`, "b")
	test(`"abc".substr(-1, 1)`, "c")
	test(`"abc".substr(-1, 2)`, "c")

	test(`"abcd".substr(3, 5)`, "d")
}
