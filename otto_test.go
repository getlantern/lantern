package otto

import (
	. "./terst"
	"math"
	"strings"
	"testing"
)

var (
	_runTestWithOtto = struct {
		Otto *Otto
		test func(string, ...interface{}) Value
	}{}
)

func failSet(name string, value interface{}) {
	err := _runTestWithOtto.Otto.Set(name, value)
	Is(err, nil)
	if err != nil {
		Terst().TestingT.FailNow()
	}
}

func runTestWithOtto() (*Otto, func(string, ...interface{}) Value) {
	cache := &_runTestWithOtto
	Otto := New()
	test := func(name string, expect ...interface{}) Value {
		raise := false
		defer func() {
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
	cache.Otto = Otto
	cache.test = test
	return Otto, test
}

func runTest() func(string, ...interface{}) Value {
	_, test := runTestWithOtto()
	return test
}

func TestTransformRegExp(t *testing.T) {
	Terst(t)

	Is(transformRegExp(`\\|'|\r|\n|\t|\u2028|\u2029`), `\\|'|\r|\n|\t|\x{2028}|\x{2029}`)
	Is(transformRegExp(`\x`), `x`)
	Is(transformRegExp(`\u0z01\x\undefined`), `u0z01xundefined`)
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
		var abc = (function(){ 1 === 1 })();
		abc;
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

func Test_typeof(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`typeof abc`, "undefined")
	test(`typeof abc === 'undefined'`, "true")
	test(`typeof {}`, "object")
	test(`typeof null`, "object")
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

	// TODO Should be: ReferenceError: ghi is not defined
	test(`ghi`, "SyntaxError: Unexpected token ILLEGAL ()")

	test(`
        function abc(){
            this.THIS = eval("this");
        }
        var def = new abc();
        def === def.THIS;
    `, "true")
}

func Test_evalDirectIndirect(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        var abc = "global";
        (function(){
            try {
                var _eval = eval;
                var abc = "function";
                if (
                    _eval("\'global\' === abc") === true &&  // eval (Indirect)
                    eval("\'function\' === abc") === true // eval (Direct)
                ) {
                    return true;
                }
                return false;
            } finally {
                delete this.abc;
            }
        })()
    `, "true")
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

	test := runTest()
	test(`var abc = eval("\"a\uFFFFa\"");`)
	test(`abc.length`, "3")
	test(`abc != "aa"`, "true")
	test("abc[1] === \"\uFFFF\"", "true")
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

func Test_stringToFloat(t *testing.T) {
	Terst(t)

	Is(stringToFloat("10e10000"), math.Inf(1))
	Is(stringToFloat("10e10_."), "NaN")
}

func Test_delete(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		delete 42;
	`, "true")

	test(`
		abc = delete $_undefined_$;
		abc = abc && delete ($_undefined_$);
        abc;
	`, "true")
}

func TestObject_defineOwnProperty(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        var object = {};

        var descriptor = new Boolean(false);
        descriptor.configurable = true;

        Object.defineProperties(object, {
            property: descriptor
        });

        var abc = object.hasOwnProperty("property");
        delete object.property;
        var def = object.hasOwnProperty("property");

		abc == true && def == false;
	`, "true")
}

func Test_assignmentEvaluationOrder(t *testing.T) {
	Terst(t)

	test := runTest()
	//test(`
	//    var abc = 0;
	//    ((abc = 1) & abc);
	//`, "1")

	test(`
        var abc = 0;
        (abc & (abc = 1));
    `, "0")
}
