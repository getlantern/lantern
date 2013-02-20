package otto

import (
	. "github.com/robertkrimen/terst"
	"testing"
)

func TestString(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = (new String("xyzzy")).length
		def = new String().length
		ghi = new String("Nothing happens.").length
	`)
	test("abc", "5")
	test("def", "0")
	test("ghi", "16")
	test(`"".length`, "0")
	test(`"a\uFFFFbc".length`, "4")
}

func TestString_charAt(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
		abc = "xyzzy".charAt(0)
		def = "xyzzy".charAt(11)
	`)
	test("abc", "x")
	test("def", "")
}

func TestString_charCodeAt(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
		abc = "xyzzy".charCodeAt(0)
		def = "xyzzy".charCodeAt(11)
	`)
	test("abc", "120")
	test("def", "NaN")
}

func TestString_concat(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`"".concat()`, "")
	test(`"".concat("abc", "def")`, "abcdef")
	test(`"".concat("abc", undefined, "def")`, "abcundefineddef")
}

func TestString_indexOf(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`"".indexOf("")`, "0")
	test(`"".indexOf("", 11)`, "0")
	test(`"abc".indexOf("")`, "0")
	test(`"abc".indexOf("", 11)`, "3")
	test(`"abc".indexOf("a")`, "0")
	test(`"abc".indexOf("bc")`, "1")
	test(`"abc".indexOf("bc", 11)`, "-1")
	test(`"$$abcdabcd".indexOf("ab", function(){return -Infinity;}())`, "2")
	test(`"$$abcdabcd".indexOf("ab", function(){return NaN;}())`, "2")
}

func TestString_lastIndexOf(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`"".lastIndexOf("")`, "0")
	test(`"".lastIndexOf("", 11)`, "0")
	test(`"abc".lastIndexOf("")`, "3")
	test(`"abc".lastIndexOf("", 11)`, "3")
	test(`"abc".lastIndexOf("a")`, "0")
	test(`"abc".lastIndexOf("bc")`, "1")
	test(`"abc".lastIndexOf("bc", 11)`, "1")
	test(`"abc".lastIndexOf("bc", 0)`, "-1")
}

func TestString_match(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`"abc____abc_abc___".match(/__abc/)`, "__abc")
	test(`"abc___abc_abc__abc__abc".match(/abc/g)`, "abc,abc,abc,abc,abc")
	test(`"abc____abc_abc___".match(/__abc/g)`, "__abc")
	test(`
		abc = /abc/g
		"abc___abc_abc__abc__abc".match(abc)
	`, "abc,abc,abc,abc,abc")
	test(`abc.lastIndex`, "23")
}

func TestString_replace(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`"abc_abc".replace(/abc/, "$&123")`, "abc123_abc")
	test(`"abc_abc".replace(/abc/g, "$&123")`, "abc123_abc123")
	test(`"abc_abc_".replace(/abc/g, "$&123")`, "abc123_abc123_")
	test(`"_abc_abc_".replace(/abc/g, "$&123")`, "_abc123_abc123_")
	test(`"abc".replace(/abc/, "$&123")`, "abc123")
	test(`"abc_".replace(/abc/, "$&123")`, "abc123_")
	test("\"^abc$\".replace(/abc/, \"$`def\")", "^^def$")
	test("\"^abc$\".replace(/abc/, \"def$`\")", "^def^$")
	test(`"_abc_abd_".replace(/ab(c|d)/g, "$1")`, "_c_d_")
	test(`
		"_abc_abd_".replace(/ab(c|d)/g, function(){
		})
	`, "_undefined_undefined_")

	test(`"b".replace(/(a)?(b)?/, "_$1_")`, "__")
	test(`
		"b".replace(/(a)?(b)?/, function(a, b, c, d, e, f){
			return [a, b, c, d, e, f]
		})
	`, "b,,b,0,b,")
}

func TestString_search(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`"abc".search(/abc/)`, "0")
	test(`"abc".search(/def/)`, "-1")
	test(`"abc".search(/c$/)`, "2")
	test(`"abc".search(/$/)`, "3")
}

func TestString_split(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`"abc".split("", 1)`, "a")
	test(`"abc".split("", 2)`, "a,b")
	test(`"abc".split("", 3)`, "a,b,c")
	test(`"abc".split("", 4)`, "a,b,c")
	test(`"abc".split("", 11)`, "a,b,c")
	test(`"abc".split("", 0)`, "")
	test(`"abc".split("")`, "a,b,c")

	test(`"abc".split(undefined)`, "abc")

	test(`"__1__3_1__2__".split("_")`, ",,1,,3,1,,2,,")

	test(`"__1__3_1__2__".split(/_/)`, ",,1,,3,1,,2,,")

	test(`"ab".split(/a*/)`, ",b")

	test(`_ = "A<B>bold</B>and<CODE>coded</CODE>".split(/<(\/)?([^<>]+)>/)`, "A,,B,bold,/,B,and,,CODE,coded,/,CODE,")
	test(`_.length`, "13")
	test(`_[1] === undefined`, "true")
	test(`_[12] === ""`, "true")
}

func TestString_slice(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`"abc".slice()`, "abc")
	test(`"abc".slice(0)`, "abc")
	test(`"abc".slice(0,11)`, "abc")
	test(`"abc".slice(0,-1)`, "ab")
	test(`"abc".slice(-1,11)`, "c")
	test(`abc = "abc"; abc.slice(abc.length+1, 0)`, "")
}

func TestString_substring(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`"abc".substring()`, "abc")
	test(`"abc".substring(0)`, "abc")
	test(`"abc".substring(0,11)`, "abc")
	test(`"abc".substring(11,0)`, "abc")
	test(`"abc".substring(0,-1)`, "")
	test(`"abc".substring(-1,11)`, "abc")
	test(`"abc".substring(11,1)`, "bc")
	test(`"abc".substring(1)`, "bc")
}

func TestString_toCase(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`"abc".toLowerCase()`, "abc")
	test(`"ABC".toLowerCase()`, "abc")
	test(`"abc".toUpperCase()`, "ABC")
	test(`"ABC".toUpperCase()`, "ABC")
}
