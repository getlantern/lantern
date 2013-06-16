package otto

import (
	. "./terst"
	"fmt"
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

	test(`
        var abc = Object.getOwnPropertyDescriptor(RegExp, "prototype");
        [   [ typeof RegExp.prototype ],
            [ abc.writable, abc.enumerable, abc.configurable ] ];
    `, "object,false,false,false")
}

func TestRegExp_global(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        var abc = /(?:ab|cd)\d?/g;
        var found = [];
        do {
            match = abc.exec("ab  cd2  ab34  cd");
            if (match !== null) {
                found.push(match[0]);
            } else {
                break;
            }
        } while (true);
        found;
    `, "ab,cd2,ab3,cd")
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

	test(`
		var abc = /[abc](\d)?/.exec("a0 b c1 d3");
        [ abc.length, abc.input, abc.index, abc ];
    `, "2,a0 b c1 d3,0,a0,0")

	test(`raise:
		var exec = RegExp.prototype.exec;
		exec("Xyzzy");
	`, "TypeError: Calling RegExp.exec on a non-RegExp object")

	test(`
        var abc = /\w{3}\d?/.exec("CE\uFFFFL\uFFDDbox127");
        [ abc.input.length, abc.length, abc.input, abc.index, abc ];
    `, "11,1,CE\uFFFFL\uFFDDbox127,5,box1")

	test(`RegExp.prototype.exec.length`, "1")
	test(`RegExp.prototype.exec.prototype`, "undefined")
}

func TestRegExp_test(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`RegExp.prototype.test.length`, "1")
	test(`RegExp.prototype.test.prototype`, "undefined")
}

func TestRegExp_toString(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`RegExp.prototype.toString.length`, "0")
	test(`RegExp.prototype.toString.prototype`, "undefined")
}

func TestRegExp_zaacbbbcac(t *testing.T) {
	Terst(t)

	test := runTest()
	if false {
		// TODO /(z)((a+)?(b+)?(c))*/.exec("zaacbbbcac")
		test(`
            var abc = /(z)((a+)?(b+)?(c))*/.exec("zaacbbbcac");
            [ abc.length, abc.index, abc ];
        `, "6,0,zaacbbbcac,z,ac,a,,c")
	}
}

func TestRegExpCopying(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        abc = /xyzzy/i;
        def = RegExp(abc);
        abc.indicator = 1;
        [ abc.indicator, def.indicator ];
    `, "1,1")

	test(`raise:
        RegExp(new RegExp("\d"), "1");
    `, "TypeError: Cannot supply flags when constructing one RegExp from another")
}

func TestRegExp_multiline(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        var abc = /s$/m.exec("pairs\nmakes\tdouble");
        [ abc.length, abc.index, abc ];
    `, "1,4,s")
}

func TestRegExp_source(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        [ /xyzzy/i.source, /./i.source ];
    `, "xyzzy,.")

	test(`
        var abc = /./i;
        var def = new RegExp(abc);
        [ abc.source, def.source, abc.source === def.source ];
    `, ".,.,true")

	test(`
        var abc = /./i;
        var def = abc.hasOwnProperty("source");
        var ghi = abc.source;
        abc.source = "xyzzy";
        [ def, abc.source ];
    `, "true,.")
}

func TestRegExp_newRegExp(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        Math.toString();
        var abc = new RegExp(Math,eval("\"g\""));
        [ abc, abc.global ];
    `, "/[object Math]/g,true")
}

func TestRegExp_flags(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        var abc = /./i;
        var def = new RegExp(abc);
        [ abc.multiline == def.multiline, abc.global == def.global, abc.ignoreCase == def.ignoreCase ];
    `, "true,true,true")
}

func TestRegExp_controlCharacter(t *testing.T) {
	Terst(t)

	test := runTest()
	for code := 0x41; code < 0x5a; code++ {
		string_ := string(code - 64)
		test(fmt.Sprintf(`
            var code = 0x%x;
            var string = String.fromCharCode(code %% 32);
            var result = (new RegExp("\\c" + String.fromCharCode(code))).exec(string);
            [ code, string, result ];
        `, code), fmt.Sprintf("%d,%s,%s", code, string_, string_))
	}
}

func TestRegExp_notNotEmptyCharacterClass(t *testing.T) {
	Terst(t)
	test := runTest()
	test(`
        var abc = /[\s\S]a/m.exec("a\naba");
        [ abc.length, abc.input, abc ];
    `, "1,a\naba,\na")
}

func TestRegExp_compile(t *testing.T) {
	Terst(t)
	test := runTest()
	test(`
        var abc = /[\s\S]a/;
        abc.compile('^\w+');
    `, "undefined")
}
