package otto

import (
	. "github.com/robertkrimen/terst"
	"testing"
)

func TestRegExp(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
		abc = new RegExp("abc").exec("123abc456")
		def = new RegExp("xyzzy").exec("123abc456")
		ghi = new RegExp("1(\\d+)").exec("123abc456")
		jkl = new RegExp("xyzzy").test("123abc456")
		mno = new RegExp("1(\\d+)").test("123abc456")
	`)
	test(`new RegExp("abc").exec("123abc456")`, "abc")
	test("def", "null")
	test("ghi", "123,23")
	test("jkl", "false")
	test("mno", "true")

	test(`new RegExp("abc").toString()`, "/abc/")
	test(`new RegExp("abc", "g").toString()`, "/abc/g")
	test(`new RegExp("abc", "mig").toString()`, "/abc/gim")

	test(`/abc/.toString()`, "/abc/")
	test(`/abc/gim.toString()`, "/abc/gim")
	test(`""+/abc/gi`, "/abc/gi")

	result := test(`/(a)?/.exec('b')`, ",")
	Is(result._object().get("0"), "")
	Is(result._object().get("1"), "undefined")
	Is(result._object().get("length"), "2")

	result = test(`/(a)?(b)?/.exec('b')`, "b,,b")
	Is(result._object().get("0"), "b")
	Is(result._object().get("1"), "undefined")
	Is(result._object().get("2"), "b")
	Is(result._object().get("length"), "3")

	test(`/\u0041/.source`, "\\u0041")
	test(`/\a/.source`, "\\a")
	test(`/\;/.source`, "\\;")

	test(`/a\a/.source`, "a\\a")
	test(`/,\;/.source`, ",\\;")
	test(`/ \ /.source`, " \\ ")

	// Start sanity check...
	test("eval(\"/abc/\").source", "abc")
	test("eval(\"/\u0023/\").source", "#")
	test("eval(\"/\u0058/\").source", "X")
	test("eval(\"/\\\u0023/\").source == \"\\\u0023\"", "true")
	test("'0x' + '0058'", "0x0058")
	test("'\\\\' + '0x' + '0058'", "\\0x0058")
	// ...stop sanity check

	test(`abc = '\\' + String.fromCharCode('0x' + '0058'); eval('/' + abc + '/').source`, "\\X")
	test(`abc = '\\' + String.fromCharCode('0x0058'); eval('/' + abc + '/').source == "\\\u0058"`, "true")
	test(`abc = '\\' + String.fromCharCode('0x0023'); eval('/' + abc + '/').source == "\\\u0023"`, "true")
	test(`abc = '\\' + String.fromCharCode('0x0078'); eval('/' + abc + '/').source == "\\\u0078"`, "true")
}

func TestRegExp_exec(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
		abc = /./g;
		def = '123456';
		ghi = 0;
		while (ghi < 100 && abc.exec(def) !== null) {
			ghi += 1;
		}
		[ ghi, def.length, ghi == def.length ];
	`, "6,6,true")

	test(`
		abc = /[abc](\d)?/g;
		def = 'a0 b c1 d3';
		ghi = 0;
		lastIndex = 0;
		while (ghi < 100 && abc.exec(def) !== null) {
			lastIndex = abc.lastIndex;
			ghi += 1;

		}
		[ ghi, lastIndex ];
	`, "3,7")

	test(`raise:
		var exec = RegExp.prototype.exec;
		exec("Xyzzy");
	`, "TypeError: Calling RegExp.exec on a non-RegExp object")
}
