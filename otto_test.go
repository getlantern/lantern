package otto

import (
    "testing"
	"fmt"
    . "github.com/robertkrimen/terst"
	"math"
	"strings"
	"unicode/utf16"
	"unicode/utf8"
)

func runTestWithOtto() (*Otto, func(string, ... interface{}) Value) {
	Otto := New()
	test := func(name string, expect... interface{}) Value {
		raise := false
		defer func(){
			if caught := recover(); caught != nil {
				if raise {
					if len(expect) > 0 {
						Is(caught, expect[0])
					}
				} else {
					dbg("Panic, caught:", caught)
					panic(caught)
				}
			}
		}()
		var value Value
		if isIdentifier(name) {
			value = Otto.getValue(name)
		} else {
			source := name
			index := strings.Index(source, "raise:")
			if index == 0 {
				raise = true
				source = source[6:]
				source = strings.TrimLeft(source, " ")
			}
			value = Otto.run(source)
		}
		value = Otto.runtime.GetValue(value)
		if len(expect) > 0 {
			Is(value, expect[0])
		}
		return value
	}
	return Otto, test
}

func runTest() func(string, ... interface{}) Value {
	_, test := runTestWithOtto()
	return test
}

func TestTransformRegExp(t *testing.T) {
	Terst(t)

	Is(transformRegExp(`\\|'|\r|\n|\t|\u2028|\u2029`), `\\|'|\r|\n|\t|\x{2028}|\x{2029}`)
	Is(transformRegExp(`\x`), `x`)
}

func TestIsValidRegExp(t *testing.T) {
	Terst(t)

	IsTrue(isValidRegExp(""))
	IsTrue(isValidRegExp("[0-9]"))
	IsTrue(isValidRegExp("[(?=(?!]"))
	IsTrue(isValidRegExp("\\(?="))
	IsTrue(isValidRegExp("(\\?!"))
	IsTrue(isValidRegExp("(?\\="))
	IsFalse(isValidRegExp("(?="))
	IsFalse(isValidRegExp("\\((?!"))
	IsFalse(isValidRegExp("[0-9](?!"))
}

func TestOtto(t *testing.T) {
	Terst(t)

	test := runTest()
	test("xyzzy = 2", "2")
	test("xyzzy + 2", "4")
	test("xyzzy += 16", "18")
	test("xyzzy", "18")
	test(`
		(function(){
			return 1
		})()
	`, "1")
	test(`
		(function(){
			return 1
		}).call(this)
	`, "1")
	test(`
		(function(){
			var result
			(function(){
				result = -1
			})()
			return result
		})()
	`, "-1")
	test(`
		var abc = 1
		abc || (abc = -1)
		abc
	`, "1")
	test(`
		var abc = (function(){ 1 === 1 })()
		abc
	`, "undefined")
}

func TestSpeed(t *testing.T) {
	Terst(t)

	return
	test := underscoreTest()
	test(`
		size = 300000
		if (false) {
			array = new Array(size)
			for (i = 0; i < array.length; i++) {
				array[i] = i
			}
		}
		else if (true) {
			Math.max.apply(Math, _.range(1, size))
		}
		else if (true) {
			_.max(_.range(1,size))
		}
		else {
			_.range(1,size)
		}
	`)
}

func TestOperator(t *testing.T) {
	Terst(t)

	Otto, test := runTestWithOtto()

    test("xyzzy = 1")
	test("xyzzy", "1")

	if true {
		Otto.Set("twoPlusTwo", func(FunctionCall) Value {
			return toValue(5)
		});
		test("twoPlusTwo( 1 )", "5")

		test("1 + twoPlusTwo( 1 )", "6")

		test("-1 + twoPlusTwo( 1 )", "4")
	}

	test("result = 4")
	test("result", "4")

    test("result += 1")
	test("result", "5")

    test("result *= 2")
	test("result", "10")

    test("result /= 2")
	test("result", "5")

    test("result = 112.51 % 3.1")
	test("result", "0.9100000000000019")

	test("result = 'Xyzzy'")
	test("result", "Xyzzy")

	test("result = 'Xyz' + 'zy'")
	test("result", "Xyzzy")

	test("result = \"Xyzzy\"")
	test("result", "Xyzzy")

	test("result = 1; result = result")
	test("result", "1")

	test(`
		var result64
		=
		64
		, result10 =
		10
	`)
	test("result64", "64")
	test("result10", "10")

	test(`
		result = 1;
		result += 1;
	`)
	test("result", "2")
}

func TestFunction(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
		result = 2
		xyzzy = function() {
			result += 1
		}
		xyzzy()
	`)
	test("result", "3")

	test(`
		xyzzy = function() {
			return 1
		}
		result = xyzzy()
	`)
	test("result", "1")

	test(`
		xyzzy = function() {}
		result = xyzzy()
	`)
	test("result", "undefined")

	test(`
		xyzzy = function() {
			return 64
			return 1
		}
		result = xyzzy()
	`)
	test("result", "64")

	test(`
		result = 4
		xyzzy = function() {
			result = 2
		}
		xyzzy()
	`)
	test("result", "2")

	test(`
		result = 4
		xyzzy = function() {
			var result
			result = 2
		}
		xyzzy()
	`)
	test("result", "4")

	test(`
		xyzzy = function() {
			var result = 4
			return result
		}
		result = xyzzy()
	`)
	test("result", "4")

	test(`
		xyzzy = function() {
			function test() {
				var result = 1
				return result
			}
			return test() + 1
		}
		result = xyzzy() + 1
	`)
	test("result", "3")

	test(`
		xyzzy = function() {
			function test() {
				var result = 1
				return result
			}
			_xyzzy = 2
			var result = _xyzzy + test() + 1
			return result
		}
		result = xyzzy() + 1
	`)
	test("result", "5")
	test("_xyzzy", "2")

	test(`
		xyzzy = function(apple) {
			return 1
		}
		result = xyzzy(1)
	`)
	test("result", "1")

	test(`
		xyzzy = function(apple) {
			return apple + 1
		}
		result = xyzzy(2)
	`)
	test("result", "3")

	test(`
		{
			result = 1
			result += 1;
		}
	`)
	test("result", "2")

	test(`
		var global = 1
		outer = function() {
			var global = 2
			var inner = function(){
				return global
			}
			return inner()
		}
		result = outer()
	`)
	test("result", "2")

	test(`
		var apple = 1
		var banana = function() {
			return apple
		}
		var cherry = function() {
			var apple = 2
			return banana()
		}
		result = cherry()
	`)
	test("result", "1")
}

func TestIf(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		if (1) {
			result = 1
		}
		else {
			result = 0
		}
	`)
	test("result", "1")

	test(`
		if (0) {
			result = 1
		}
		else {
			result = 0
		}
	`)
	test("result", "0")

	test(`
		result = 0
		if (0) {
			result = 1
		}
	`)
	test("result", "0")

	test(`
		result = 0
		if (result) {
			result = 1
		}
	`)
	test("result", "0")
}

func TestDoWhile(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		limit = 4
		result = 0
		do { 
			result = result + 1
			limit = limit - 1
		}
		while (limit)
	`)
	test("result", "4")
}

func TestWhile(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		limit = 4
		result = 0
		while (limit) {
			result = result + 1
			limit = limit - 1
		}
	`)
	test("result", "4")
}

func TestContinueBreak(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		limit = 4
		result = 0
		while (limit) {
			limit = limit - 1
			if (limit) {
			}
			else {
				break
			}
			result = result + 1
		}
	`)
	test("result", "3")
	test("limit", "0")

	test(`
		limit = 4
		result = 0
		while (limit) {
			limit = limit - 1
			if (limit) {
				continue
			}
			else {
				break
			}
			result = result + 1
		}
	`)
	test("result", "0")

	test(`
		limit = 4
		result = 0
		do {
			limit = limit - 1
			if (limit) {
				continue
			}
			else {
				break
			}
			result = result + 1
		} while (limit)
	`)
	test("result", "0")
}

func TestSwitchBreak(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		var abc = true;
		var ghi = "Xyzzy";
		while (abc) {
			switch ('def') {
			case 'def':
				break;
			}
			ghi = "Nothing happens."
			abc = false
		}
		ghi
	`, "Nothing happens.")

	test(`
		var abc = true;
		var ghi = "Xyzzy";
		WHILE:
		while (abc) {
			switch ('def') {
			case 'def':
				break WHILE;
			}
			ghi = "Nothing happens."
			abc = false
		}
		ghi
	`, "Xyzzy")

	test(`
		var ghi = "Xyzzy";
		FOR:
		for (;;) {
			switch ('def') {
			case 'def':
				break FOR;
				ghi = ""
			}
			ghi = "Nothing happens."
		}
		ghi
	`, "Xyzzy")

	test(`
		var ghi = "Xyzzy";
		FOR:
		for (var jkl in {}) {
			switch ('def') {
			case 'def':
				break FOR;
				ghi = "Something happens."
			}
			ghi = "Nothing happens."
		}
		ghi
	`, "Xyzzy")

	test(`
		var ghi = "Xyzzy";
		function jkl() {
			switch ('def') {
			case 'def':
				break;
				ghi = ""
			}
			ghi = "Nothing happens."
		}
		while (abc) {
			jkl()
			abc = false
			ghi = "Something happens."
		}
		ghi
	`, "Something happens.")
}

func TestTryFinally(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		try {
			result = 1
		}
		finally {
			result = 2
		}
	`)
	test("result", "2")
}

func TestTryCatch(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		result = 1
		try {
			throw 4
			result = -1
		}
		catch (xyzzy) {
			result += xyzzy + 1
		}
	`)
	test("result", "6")

	test(`
		result = 1
		try {
			try {
				throw 4
				result = -1
			}
			catch (xyzzy) {
				result += xyzzy + 1
				throw 64
			}
		}
		catch (xyzzy) {
			resultXyzzy = xyzzy
			result = -2
		}
	`)
	test("resultXyzzy", "64")
	test("result", "-2")
}

func TestTryCatchError(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		var abc
		try {
			1()
		}
		catch (def) {
			abc = def
		}
		abc
	`, "TypeError: 1 is not a function")

}

func TestPositiveNegativeZero(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`1/0`, "Infinity")
	test(`1/-0`, "-Infinity")
	test(`
		abc = -0
		1/abc
	`,
	"-Infinity",
	)
}

func TestDate(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`Date`, "[function]")
	test(`new Date(0).toUTCString()`, "Thu, 01 Jan 1970 00:00:00 UTC")
	test(`new Date(1348616313).getTime()`, "1348616313")
	// TODO These shold be in local time
	test(`new Date(1348616313).toUTCString()`, "Fri, 16 Jan 1970 14:36:56 UTC")
	test(`abc = new Date(1348616313047); abc.toUTCString()`, "Tue, 25 Sep 2012 23:38:33 UTC")
	test(`abc.getFullYear()`, "2012")
	test(`abc.getUTCFullYear()`, "2012")
	test(`abc.getMonth()`, "8") // Remember, the JavaScript month is 0-based
	test(`abc.getUTCMonth()`, "8")
	test(`abc.getDate()`, "25")
	test(`abc.getUTCDate()`, "25")
	test(`abc.getDay()`, "2")
	test(`abc.getUTCDay()`, "2")
	test(`abc.getHours()`, "16")
	test(`abc.getUTCHours()`, "23")
	test(`abc.getMinutes()`, "38")
	test(`abc.getUTCMinutes()`, "38")
	test(`abc.getSeconds()`, "33")
	test(`abc.getUTCSeconds()`, "33")
	test(`abc.getMilliseconds()`, "47") // In honor of the 47%
	test(`abc.getUTCMilliseconds()`, "47")
	test(`abc.getTimezoneOffset()`, "420")
	if false {
		// TODO (When parsing is implemented)
		test(`new Date("Xyzzy").getTime()`, "NaN")
	}

	test(`abc.setFullYear(2011); abc.toUTCString()`, "Sun, 25 Sep 2011 23:38:33 UTC")
	test(`new Date(12564504e5).toUTCString()`, "Sun, 25 Oct 2009 06:00:00 UTC")
	test(`new Date(2009, 9, 25).toUTCString()`, "Sun, 25 Oct 2009 00:00:00 UTC")
	test(`+(new Date(2009, 9, 25))`, "1.2564288e+12")

	test(`abc = new Date(12564504e5); abc.setMilliseconds(2001); abc.toUTCString()`, "Sun, 25 Oct 2009 06:00:02 UTC")

	test(`abc = new Date(12564504e5); abc.setSeconds("61"); abc.toUTCString()`, "Sun, 25 Oct 2009 06:01:01 UTC")

	test(`abc = new Date(12564504e5); abc.setMinutes("61"); abc.toUTCString()`, "Sun, 25 Oct 2009 07:01:00 UTC")

	test(`abc = new Date(12564504e5); abc.setHours("5"); abc.toUTCString()`, "Sat, 24 Oct 2009 12:00:00 UTC")

	test(`abc = new Date(12564504e5); abc.setDate("26"); abc.toUTCString()`, "Tue, 27 Oct 2009 06:00:00 UTC")

	test(`abc = new Date(12564504e5); abc.setMonth(9); abc.toUTCString()`, "Sun, 25 Oct 2009 06:00:00 UTC")
	test(`abc = new Date(12564504e5); abc.setMonth("09"); abc.toUTCString()`, "Sun, 25 Oct 2009 06:00:00 UTC")
	test(`abc = new Date(12564504e5); abc.setMonth("10"); abc.toUTCString()`, "Wed, 25 Nov 2009 07:00:00 UTC")

	test(`abc = new Date(12564504e5); abc.setFullYear(2010); abc.toUTCString()`, "Mon, 25 Oct 2010 06:00:00 UTC")
}

func TestComparison(t *testing.T) {
	Terst(t)

	test := runTest()

	test("undefined = 1")
	test("undefined", "1")

	test("result = undefined == undefined")
	test("result", "true")

	test("result = undefined != undefined")
	test("result", "false")

	test("result = null == null")
	test("result", "true")

	test("result = null != null")
	test("result", "false")

	test("result = 0 == 1")
	test("result", "false")

	Is(negativeZero(), "-0")
	Is(positiveZero(), "0")
	IsTrue(math.Signbit(negativeZero()))
	IsTrue(positiveZero() == negativeZero())

	test("result = 1 == 1")
	test("result", "true")

	test("result = 'Hello, World.' == 'Goodbye, World.'")
	test("result", "false")

	test("result = 'Hello, World.' == true")
	test("result", "false")

	test("result = 'Hello, World.' == false")
	test("result", "false")

	test("result = 'Hello, World.' == 1")
	test("result", "false")

	test("result = 1 == 'Hello, World.'")
	test("result", "false")

	Is(stringToFloat("-1"), -1)

	if false {
		fmt.Printf("Hello, World.: %v", toNumber(toValue("Hello, World.")))
	}

	test("result = 0+Object")
	test("result", "0[function]")
}

func TestComparisonRelational(t *testing.T) {
	Terst(t)

	test := runTest()

	test("result = 0 < 0")
	test("result", "false")

	test("result = 0 > 0")
	test("result", "false")

	test("result = 0 <= 0")
	test("result", "true")

	test("result = 0 >= 0")
	test("result", "true")

	test("result = '   0' >= 0")
	test("result", "true")

	test("result = '_   0' >= 0")
	test("result", "false")
}

func TestSwitch(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		result = 0
		switch (0) {
		default:
			result += 1 
		case 1:
			result += 2
		case 2:
			result += 4
		case 3:
			result += 8 
		}
	`)
	test("result", "15")

	test(`
		result = 0
		switch (3) {
		default:
			result += 1 
		case 1:
			result += 2
		case 2:
			result += 4
		case 3:
			result += 8 
		}
	`)
	test("result", "8")

	test(`
		result = 0
		switch (60) {
		case 1:
			result += 2
		case 2:
			result += 4
		case 3:
			result += 8 
		}
	`)
	test("result", "0")
}

func TestFor(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		result = 7
		for (i = 0; i < 3; i += 1) {
			result += 1
		}
	`)
	test("result", "10")

	test(`
		result = 7
		for (i = 0; i < 3; i += 1) {
			result += 1
			if (i == 1) {
				break
			}
		}
	`)
	test("result", "9")

	test(`
		result = 7
		for (i = 0; i < 3; i += 1) {
			if (i == 2) {
				continue
			}
			result += 1
		}
	`)
	test("result", "9")

	test(`
		abc = 0
		for (;;) {
			abc += 1
			if (abc == 3)
				break
		}
		abc
	`, "3")

	test(`
		for (abc = 0; ;) {
			abc += 1
			if (abc == 3)
				break
		}
		abc
	`, "3")

	test(`
		for (abc = 0; ; abc+=1) {
			abc += 1
			if (abc == 3)
				break
		}
		abc
	`, "3")
}

func TestArguments(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
		xyzzy = function() {
			return arguments[0]
		}
		result = xyzzy("xyzzy")
	`)
	test("result", "xyzzy")

	test(`
		xyzzy = function() {
			arguments[0] = "abcdef"
			return arguments[0]
		}
		result = xyzzy("xyzzy")
	`)
	test("result", "abcdef")

	test(`
		xyzzy = function(apple) {
			apple = "abcdef"
			return arguments[0]
		}
		result = xyzzy("xyzzy")
	`)
	test("result", "abcdef")

	test(`
		(function(){
			return arguments
		})()
	`, "[object Arguments]")

	test(`
		(function(){
			return arguments.length
		})()
	`, "0")

	test(`
		(function(){
			return arguments.length
		})(1, 2, 4, 8, 10)
	`, "5")
}

func TestObjectLiteral(t *testing.T) {
	Terst(t)

	Otto := New()
	Otto.Run(`
		result = {}
	`)
	IsTrue(Otto.getValue("result").IsObject())

	Otto.Run(`
		result = { xyzzy: "Nothing happens.", 0: 1 }
	`)
	Is(Otto.getValue("result")._object().GetValue("xyzzy"), "Nothing happens.")
}

func TestArrayLiteral(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
		result = []
	`)
	IsTrue(test("result").IsObject())

	test(`
		result = [ "Nothing happens.", 0, 1 ]
	`)
	Is(test("result")._object().GetValue("0"), "Nothing happens.")

	test(`
		xyzzy = [ "Nothing happens.", 0, 1 ]
		result = xyzzy[1]
	`)
	test("result", "0")

	test(`
		xyzzy = [ "Nothing happens.", 0, 1 ]
		xyzzy[10] = 2
		_6 = xyzzy[6]
		result = xyzzy[10]
	`)
	test("result", "2")
	test("_6", "undefined")
}

func TestUnaryPrefix (t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		result = 0
		++result
	`)
	test("result", "1")

	test(`
		result = 0
		--result
	`)
	test("result", "-1")
}

func TestUnaryPostfix (t *testing.T) {
	Terst(t)

	test := runTest()

	result := test(`
		result = 0
		result++
		result++
	`)
	Is(result, "1")
	test("result", "2")

	result = test(`
		result = 0
		result--
		result--
	`)
	Is(result, "-1")
	test("result", "-2")
}

func TestBinaryLogicalOperation (t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = true
		def = false
		ghi = false
		jkl = false
		result = abc && def || ghi && jkl
	`)
	test("result", "false")

	test(`
		abc = true
		def = true
		ghi = false
		jkl = false
		result = abc && def || ghi && jkl
	`)
	test("result", "true")

}

func TestBinaryBitwiseOperation (t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = 1 & 2
		def = 1 & 3
		ghi = 1 | 3
		jkl = 1 ^ 2
		mno = 1 ^ 3

	`)
	test("abc", "0")
	test("def", "1")
	test("ghi", "3")
	test("jkl", "3")
	test("mno", "2")
}

func TestBinaryShiftOperation (t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		high = (1 << 30) - 1 + (1 << 30)
		low = -high - 1
		abc = 23 << 1
		def = -105 >> 1
		ghi = 23 << 2
		jkl = 1 >>> 31
		mno = 1 << 64
		pqr = 1 >> 2
		stu = -2 >> 4
		vwx = low >> 1
		yz = low >>> 1
	`)
	test("abc", "46")
	test("def", "-53")
	test("ghi", "92")
	test("jkl", "0")
	test("mno", "1")
	test("pqr", "0")
	test("stu", "-1")
	test("vwx", "-1073741824")
	test("yz", "1073741824")

}

func TestParenthesizing (t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = 1 + 2 * 3
		def = (1 + 2) * 3
		ghi = !(false || true)
		jkl = !false || true
	`)
	test("abc", "7")
	test("def", "9")
	test("ghi", "false")
	test("jkl", "true")
}

func TestInstanceOf (t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = {} instanceof Object
	`)
	test("abc", "true")
}

func TestIn (t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = "prototype" in Object
		def = "xyzzy" in Object
	`)
	test("abc", "true")
	test("def", "false")
}

func TestForIn (t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		for (property in { a: 1 }) {
			abc = property
		}
	`)
	test("abc", "a")

	test(`
		for (property in new String("xyzzy")) {
			abc = property
		}
	`)
	test("abc", "4")
}

func TestAssignment(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = 1
		def = abc
	`)
	test("abc", "1")
	test("def", "1")
}

func Testnew(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = new Boolean
		def = new Boolean(1)
	`)
	test("abc", "false")
	test("def", "true")
}

func TestConditional(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = true ? 1 : 0
		def = 0 ? 2 : 3
	`)
	test("abc", "1")
	test("def", "3")
}

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
}

func TestArray(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = ""+[0, 1, 2, 3]
		def = [].toString()
		ghi = [null, 4, "null"].toString()
	`)
	test("abc", "0,1,2,3")
	test("def", "")
	test("ghi", ",4,null")
	test(`new Array(0).length`, "0")
	test(`new Array(11).length`, "11")
	test(`new Array(11, 1).length`, "2")
}

func TestArray_toString(t *testing.T) {
	Terst(t)

	{
		test := runTest()

		test(`
			Array.prototype.toString = function() {
				return "Nothing happens."
			}
			abc = Array.prototype.toString()
			def = [].toString()
			ghi = [null, 4, "null"].toString()
		`)
		test("abc", "Nothing happens.")
		test("def", "Nothing happens.")
		test("ghi", "Nothing happens.")

	}

	{
		test := runTest()

		test(`
			Array.prototype.join = undefined
			abc = Array.prototype.toString()
			def = [].toString()
			ghi = [null, 4, "null"].toString()
		`)
		test("abc", "[object Array]")
		test("def", "[object Array]")
		test("ghi", "[object Array]")
	}
}

func TestArray_concat(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = [0, 1, 2]
		def = [-1, -2, -3]
		ghi = abc.concat(def)
		jkl = abc.concat(def, 3, 4, 5)
		mno = def.concat(-4, -5, abc)
	`)
	test("ghi", "0,1,2,-1,-2,-3")
	test("jkl", "0,1,2,-1,-2,-3,3,4,5")
	test("mno", "-1,-2,-3,-4,-5,0,1,2")
}

func TestArray_splice(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = [0, 1, 2]
		def = abc.splice(1, 2, 3, 4, 5)
		ghi = [].concat(abc)
		jkl = ghi.splice(17, 21, 7, 8, 9)
	`)
	test("abc", "0,3,4,5")
	test("def", "1,2")
	test("ghi", "0,3,4,5,7,8,9")
	test("jkl", "")
}

func TestArray_shift(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = [0, 1, 2]
		def = abc.shift()
		ghi = [].concat(abc)
		jkl = abc.shift()
		mno = [].concat(abc)
		pqr = abc.shift()
		stu = [].concat(abc)
		vwx = abc.shift()
	`)
	test("abc", "")
	test("def", "0")
	test("ghi", "1,2")
	test("jkl", "1")
	test("mno", "2")
	test("pqr", "2")
	test("stu", "")
	test("vwx", "undefined")
}

func TestArray_push(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = [0]
		def = abc.push(1)
		ghi = [].concat(abc)
		jkl = abc.push(2,3,4)
	`)
	test("abc", "0,1,2,3,4")
	test("def", "2")
	test("ghi", "0,1")
	test("jkl", "5")
}

func TestArray_pop(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = [0,1]
		def = abc.pop()
		ghi = [].concat(abc)
		jkl = abc.pop()
		mno = [].concat(abc)
		pqr = abc.pop()
	`)
	test("abc", "")
	test("def", "1")
	test("ghi", "0")
	test("jkl", "0")
	test("mno", "")
	test("pqr", "undefined")
}

func TestArray_slice(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = [0,1,2,3]
		def = abc.slice()
		ghi = abc.slice(1)
		jkl = abc.slice(3,-1)
		mno = abc.slice(2,-1)
		pqr = abc.slice(-1, -10)
	`)
	test("def", "0,1,2,3")
	test("ghi", "1,2,3")
	test("jkl", "")
	test("mno", "2")
	test("pqr", "")
	test(`abc.slice(2, 2)`, "")
	test(`abc.slice(2, 3)`, "2")

	test(`
		abc = { 0: 0, 1: 1, 2: 2, 3: 3 }
		abc.length = 4
		def = Array.prototype.slice.call(abc)
		ghi = Array.prototype.slice.call(abc,1)
		jkl = Array.prototype.slice.call(abc,3,-1)
		mno = Array.prototype.slice.call(abc,2,-1)
		pqr = Array.prototype.slice.call(abc,-1,-10)
	`)
	// Array.protoype.slice is generic
	test("def", "0,1,2,3")
	test("ghi", "1,2,3")
	test("jkl", "")
	test("mno", "2")
	test("pqr", "")
}

func TestArray_sliceArguments(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		(function(){
			return Array.prototype.slice.call(arguments, 1)
		})({}, 1, 2, 3)
	`, "1,2,3")

}

func TestArray_unshift(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = []
		def = abc.unshift(0)
		ghi = [].concat(abc)
		jkl = abc.unshift(1,2,3,4)
	`)
	test("abc", "1,2,3,4,0")
	test("def", "1")
	test("ghi", "0")
	test("jkl", "5")
}

func TestArray_reverse(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = [0,1,2,3].reverse()
		def = [0,1,2].reverse()
	`)
	test("abc", "3,2,1,0")
	test("def", "2,1,0")
}

func TestArray_sort(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = [0,1,2,3].sort()
		def = [3,2,1,0].sort()
		ghi = [].sort()
		jkl = [0].sort()
		mno = [1,0].sort()
		pqr = [1,5,-10, 100, 8, 72, 401, 0.05].sort()
		stu = [1,5,-10, 100, 8, 72, 401, 0.05].sort(function(x, y){
			return x == y ? 0 : x < y ? -1 : 1
		})
	`)
	test("abc", "0,1,2,3")
	test("def", "0,1,2,3")
	test("ghi", "")
	test("jkl", "0")
	test("mno", "0,1")
	test("pqr", "-10,0.05,1,100,401,5,72,8")
	test("stu", "-10,0.05,1,5,8,72,100,401")
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
	Is(result._object().Get("0"), "")
	Is(result._object().Get("1"), "undefined")
	Is(result._object().Get("length"), "2")

	result = test(`/(a)?(b)?/.exec('b')`, "b,,b")
	Is(result._object().Get("0"), "b")
	Is(result._object().Get("1"), "undefined")
	Is(result._object().Get("2"), "b")
	Is(result._object().Get("length"), "3")

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

func TestNewFunction(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		new Function("return 11")()
	`, "11")

	test(`
		abc = 10
		new Function("abc += 1")()
		abc
	`, "11")

	test(`
		new Function("a", "b", "c", "return b + 2")(10, 11, 12)
	`, "13")

	test(`raise:
		new 1
	`, "TypeError: 1 is not a function")

	// TODO Report something sane.
	test(`raise:
		new this
	`, "TypeError:  is not a function")

	test(`raise:
		new {}
	`, "TypeError: [object Object] is not a function")
}

func TestNewPrototype(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = { 'xyzzy': 'Nothing happens.' }
		function Xyzzy(){}
		Xyzzy.prototype = abc;
		(new Xyzzy()).xyzzy
	`, "Nothing happens.")
}

func TestWith(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		var def
		with({ abc: 9 }) {
			def = abc
		}
		def
	`, "9")

	test(`
		var def
		with({ abc: function(){
			return 11
		} }) {
			def = abc()
		}
		def
	`, "11")
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
}

func TestString_substring(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`"abc".substring()`, "")
	test(`"abc".substring(0)`, "")
	test(`"abc".substring(0,11)`, "abc")
	test(`"abc".substring(11,0)`, "abc")
	test(`"abc".substring(0,-1)`, "")
	test(`"abc".substring(-1,11)`, "abc")
	test(`"abc".substring(11,1)`, "bc")
}

func TestString_toCase(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`"abc".toLowerCase()`, "abc")
	test(`"ABC".toLowerCase()`, "abc")
	test(`"abc".toUpperCase()`, "ABC")
	test(`"ABC".toUpperCase()`, "ABC")
}

func TestMath_max(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.max(-11, -1, 0, 1, 2, 3, 11)`, "11")
}

func TestMath_min(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.min(-11, -1, 0, 1, 2, 3, 11)`, "-11")
}

func TestMath_ceil(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.ceil(-11)`, "-11")
	test(`Math.ceil(-0.5)`, "-0")
	test(`Math.ceil(1.5)`, "2")
}

func TestMath_floor(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.floor(-11)`, "-11")
	test(`Math.floor(-0.5)`, "-1")
	test(`Math.floor(1.5)`, "1")
}

func TestFunction_apply(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`String.prototype.substring.length`, "2")
	test(`String.prototype.substring.apply("abc", [1, 11])`, "bc")
}

func TestFunction_call(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`String.prototype.substring.length`, "2")
	test(`String.prototype.substring.call("abc", 1, 11)`, "bc")
}

func Test_typeof(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`typeof abc`, "undefined")
	test(`typeof abc === 'undefined'`, "true")
}

func Test_PrimitiveValueObjectValue(t *testing.T) {
	Terst(t)

	test := runTest()
	Number11 := test(`new Number(11)`)
	Is(toFloat(Number11), "11")
}

func Test_eval(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = 1
	`)

	test(`
		eval("abc += 1")
	`, "2")

	test(`
		(function(){
			var abc = 11
			eval("abc += 1")
			return abc
		})()
	`, "12")
	test(`abc`, "2")

	test(`
		var ghi;
		(function(){
			try {
				eval("var prop = \\u2029;");
				return false;
			} catch (abc) {
				ghi = abc.toString()
				return abc instanceof SyntaxError;
			}
		})()
	`, "true")
	// TODO Make this a sane result
	// Lightning bolt, lightning bolt, lightning bolt, ...
	test(`ghi`, "SyntaxError: SyntaxError: SyntaxError: Unexpected token ILLEGAL ()")
}

func Test_isNaN(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`isNaN(0)`, "false")
	test(`isNaN("Xyzzy")`, "true")
	test(`isNaN()`, "true")
	test(`isNaN(NaN)`, "true")
	test(`isNaN(Infinity)`, "false")
}

func Test_isFinite(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`isFinite(0)`, "true")
	test(`isFinite("Xyzzy")`, "false")
	test(`isFinite()`, "false")
	test(`isFinite(NaN)`, "false")
	test(`isFinite(Infinity)`, "false")
}

func Test_parseInt(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`parseInt("0")`, "0")
	test(`parseInt("11")`, "11")
	test(`parseInt(" 11")`, "11")
	test(`parseInt("11 ")`, "11")
	test(`parseInt(" 11 ")`, "11")
	test(`parseInt(" 11\n")`, "11")
	test(`parseInt(" 11\n", 16)`, "17")
	test(`parseInt("Xyzzy")`, "NaN")
	test(`parseInt("0x0a")`, "10")
	if false {
		test(`parseInt(" 0x11\n", 16)`, "17")
		// TODO parseInt should return 10 in this scenario
		test(`parseInt("0x0aXyzzy")`, "10")
	}
}

func Test_parseFloat(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`parseFloat("0")`, "0")
	test(`parseFloat("11")`, "11")
	test(`parseFloat(" 11")`, "11")
	test(`parseFloat("11 ")`, "11")
	test(`parseFloat(" 11 ")`, "11")
	test(`parseFloat(" 11\n")`, "11")
	test(`parseFloat(" 11\n", 16)`, "11")
	test(`parseFloat("Xyzzy")`, "NaN")
	test(`parseFloat("0x0a")`, "NaN")
	test(`parseFloat("11.1")`, "11.1")
	if false {
		test(`parseFloat(" 0x11\n", 16)`, "17")
		// TODO parseFloat should return 10 in this scenario
		test(`parseFloat("0x0aXyzzy")`, "10")
	}
}

func Test_encodeURI(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`encodeURI("http://example.com/ Nothing happens.")`, "http://example.com/%20Nothing%20happens.")
	test(`encodeURI("http://example.com/ _^#")`, "http://example.com/%20_%5E#")
}

func Test_encodeURIComponent(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`encodeURIComponent("http://example.com/ Nothing happens.")`, "http%3A%2F%2Fexample.com%2F%20Nothing%20happens.")
	test(`encodeURIComponent("http://example.com/ _^#")`, "http%3A%2F%2Fexample.com%2F%20_%5E%23")
}

func Test_decodeURI(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`decodeURI(encodeURI("http://example.com/ Nothing happens."))`, "http://example.com/ Nothing happens.")
	test(`decodeURI(encodeURI("http://example.com/ _^#"))`, "http://example.com/ _^#")
	test(`raise: decodeURI("http://example.com/ _^#%")`, "URIError: URI malformed")
}

func Test_decodeURIComponent(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`decodeURIComponent(encodeURI("http://example.com/ Nothing happens."))`, "http://example.com/ Nothing happens.")
	test(`decodeURIComponent(encodeURI("http://example.com/ _^#"))`, "http://example.com/ _^#")
}

func TestError(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`new URIError() instanceof URIError`, "true")
	test(`
		var abc
		try {
			decodeURI("http://example.com/ _^#%")
		}
		catch (def) {
			abc = def instanceof URIError
		}
		abc
	`, "true")
}

func TestTo(t *testing.T) {
	Terst(t)

	test := runTest()

	{
		value, _ := test(`"11"`).ToFloat()
		Is(value, float64(11))
	}

	{
		value, _ := test(`"11"`).ToInteger()
		Is(value, int64(11))

		value, _ = test(`1.1`).ToInteger()
		Is(value, int64(1))
	}
}

func TestShouldError(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`raise:
		xyzzy
			throw new TypeError("Nothing happens.")
	`, "ReferenceError: xyzzy is not defined")
}

func TestAPI(t *testing.T) {
	Terst(t)

	Otto, test := runTestWithOtto()
	test(`
		String.prototype.xyzzy = function(){
			console.log(this)
			return this.length + 11 + (arguments[0] || 0)
		}
		abc = new String("xyzzy")
		def = "Nothing happens."
		abc.xyzzy()
	`, "16")
	abc, _ := Otto.Get("abc")
	def, _ := Otto.Get("def")
	object := abc.Object()
	result, _ := object.Call("xyzzy")
	Is(result, "16")
	result, _ = object.Call("xyzzy", 1)
	Is(result, "17")
	value, _ := object.Get("xyzzy")
	result, _ = value.Call(def)
	Is(result, "27")
	result, _ = value.Call(def, 3)
	Is(result, "30")
	object = value.Object() // Object xyzzy
	result, _ = object.Value().Call(def, 3)
	Is(result, "30")
}

func TestUnicode(t *testing.T) {
	Terst(t)

	if false {
		// TODO This test will fail because we handle strings internally the
		// same way Go does, UTF-8
		test := runTest()
		test(`var abc = eval("\"a\uFFFFa\"");`)
		test(`abc.length`, "3")
		test(`abc != "aa"`, "true")
		test("abc[1] === \"\uFFFF\"", "true")
		dbg(utf8.RuneLen('\u000a'))
		dbg(len(utf16.Encode([]rune("a\uFFFFa"))))
	}
}

func TestDotMember(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = {
			ghi: 11,
		}
		abc.def = "Xyzzy"
		abc.null = "Nothing happens."
	`)
	test(`abc.def`, "Xyzzy")
	test(`abc.null`, "Nothing happens.")
	test(`abc.ghi`, "11")

	test(`
		abc = {
			null: 11,
		}
	`)
	test(`abc.def`, "undefined")
	test(`abc.null`, "11")
	test(`abc.ghi`, "undefined")
}

