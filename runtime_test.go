package otto

import (
	. "./terst"
	"math"
	"testing"
)

func TestOperator(t *testing.T) {
	Terst(t)

	Otto, test := runTestWithOtto()

	test("xyzzy = 1")
	test("xyzzy", "1")

	if true {
		Otto.Set("twoPlusTwo", func(FunctionCall) Value {
			return toValue(5)
		})
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

func TestFunction_(t *testing.T) {
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

	test(`
        function xyz() {
        };
        delete xyz;
    `, "false")

	test(`
        var abc = function __factorial(def){
            if (def === 1) {
                return def;
            } else {
                return __factorial(def-1)*def;
            }
        };
        abc(3);
    `, "6")
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
		limit = 4;
		result = 0;
		do { 
			result = result + 1;
			limit = limit - 1;
		} while (limit);
        result;
	`, "4")

	test(`
        result = eval("do {abc=1; break; abc=2;} while (0);");
        [ result, abc ];
    `, "1,1")
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

	test(`
		var abc = false, def = 0;
		do {
			def += 1;
			if (def > 100) {
				break;
			}
			try {
				continue;
			}
			finally {
				abc = true;
			}
		}
		while(!abc && def < 10)
		def;
	`, "1")

	test(`
		var abc = false, def = 0, ghi = 0;
		do {
			def += 1;
			if (def > 100) {
				break;
			}
			try {
				throw 0;
			}
			catch (jkl) {
				continue;
			}
			finally {
				abc = true;
				ghi = 11;
			}
			ghi -= 1;
		}
		while(!abc && def < 10)
		ghi;
	`, "11")

	test(`
        var abc = 0, def = 0;
        do {
            try {
                abc += 1;
                throw "ghi";
            }
            finally {
                def = 1;
                continue;
            }   
            def -= 1;
        }
        while (abc < 2)
        [ abc, def ];
    `, "2,1")
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

func TestComparison(t *testing.T) {
	Terst(t)

	test := runTest()

	test("undefined = 1")
	test("undefined", "undefined")

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
    xyzzy: for (var abc = 0; abc <= 0; abc++) {
    for (var def = 0; def <= 1; def++) {
        if (def === 0) {
            continue xyzzy;
            } else {
            }
        }  
    }
    `)

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
	Is(Otto.getValue("result")._object().get("xyzzy"), "Nothing happens.")
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
	Is(test("result")._object().get("0"), "Nothing happens.")

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

func TestUnaryPrefix(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		var result = 0;
		[++result, result];
	`, "1,1")

	test(`
		result = 0;
		[--result, result];
	`, "-1,-1")

	test(`
        var object = { valueOf: function() { return 1; } };
        result = ++object;
        [ result, typeof result ];
    `, "2,number")

	test(`
        var object = { valueOf: function() { return 1; } };
        result = --object;
        [ result, typeof result ];
    `, "0,number")
}

func TestUnaryPostfix(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		var result = 0;
		result++;
		[ result++, result ];
	`, "1,2")

	test(`
		result = 0;
		result--;
		[ result--, result ];
	`, "-1,-2")

	test(`
        var object = { valueOf: function() { return 1; } };
        result = object++;
        [ result, typeof result ];
    `, "1,number")

	test(`
        var object = { valueOf: function() { return 1; } };
        result = object--
        [ result, typeof result ];
    `, "1,number")
}

func TestBinaryLogicalOperation(t *testing.T) {
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

func TestBinaryBitwiseOperation(t *testing.T) {
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

func TestBinaryShiftOperation(t *testing.T) {
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

func TestParenthesizing(t *testing.T) {
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

func Test_instanceof(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = {} instanceof Object;
	`)
	test("abc", "true")

	test(`
		abc = "abc" instanceof Object;
	`)
	test("abc", "false")

	test(`raise:
		abc = {} instanceof "abc";
    `, "TypeError: Expecting a function in instanceof check, but got: abc")

	test(`raise:
        "xyzzy" instanceof Math;
    `, "TypeError")
}

func TestIn(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		abc = "prototype" in Object
		def = "xyzzy" in Object
	`)
	test("abc", "true")
	test("def", "false")
}

func TestForIn(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        var abc;
		for (property in { a: 1 }) {
			abc = property;
		}
        abc;
	`, "a")

	test(`
        var ghi;
		for (property in new String("xyzzy")) {
			ghi = property;
		}
        ghi;
	`, "4")
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

	// TODO Better error reporting: new this
	test(`raise:
		new this
	`, "TypeError: [object environment] is not a function")

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

func TestBlock(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        var abc=0;
        var ghi;
        def: {
            do {
                abc++;
                if (!(abc < 10)) {
                    break def;
                    ghi = "ghi";
                }
            } while (true);
        }
        [ abc,ghi ];
    `, "10,")
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

func Test_toString(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        [undefined+""]
    `, "undefined")
}

func TestEvaluationOrder(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        var abc = 0;
        abc < (abc = 1) === true;
    `, "true")
}

func TestClone(t *testing.T) {
	Terst(t)

	otto1 := New()
	otto1.Run(`
        var abc = 1;
    `)

	otto2 := otto1.clone()
	otto1.Run(`
        abc += 2;
    `)
	otto2.Run(`
        abc += 4;
    `)

	Is(otto1.getValue("abc"), "3")
	Is(otto2.getValue("abc"), "5")
}
