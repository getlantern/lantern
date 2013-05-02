package otto

import (
	. "./terst"
	"testing"
)

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

func Test_builtin_escape(t *testing.T) {
	Terst(t)

	Is(builtin_escape("abc"), "abc")
	Is(builtin_escape("="), "%3D")
	Is(builtin_escape("abc=%+32"), "abc%3D%25+32")
	Is(builtin_escape("世界"), "%u4E16%u754C")
}

func Test_builtin_unescape(t *testing.T) {
	Terst(t)

	Is(builtin_unescape("abc"), "abc")
	Is(builtin_unescape("=%3D"), "==")
	Is(builtin_unescape("abc%3D%25+32"), "abc=%+32")
	Is(builtin_unescape("%u4E16%u754C"), "世界")
}

func TestGlobal_escape(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`escape("abc")`, "abc")
	test(`escape("=")`, "%3D")
	test(`escape("abc=%+32")`, "abc%3D%25+32")
	test(`escape("\u4e16\u754c")`, "%u4E16%u754C")
}

func TestGlobal_unescape(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`unescape("abc")`, "abc")
	test(`unescape("=%3D")`, "==")
	test(`unescape("abc%3D%25+32")`, "abc=%+32")
	test(`unescape("%u4E16%u754C")`, "世界")
}
