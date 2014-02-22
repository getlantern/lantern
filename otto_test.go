package otto

import (
	. "./terst"
	"github.com/robertkrimen/otto/underscore"
	"math"
	"strings"
	"testing"
)

var (
	_newOttoClone = false
	_newOtto      = map[string]*Otto{}

	_runTestWithOtto = struct {
		Otto *Otto
		test func(string, ...interface{}) Value
	}{}
)

func newOtto(kind string, setup func(otto *Otto)) *Otto {
	if _newOttoClone {
		otto := _newOtto[kind]
		if otto == nil {
			otto = New()
			if setup != nil {
				setup(otto)
			}
			_newOtto[kind] = otto
		}
		return otto.clone()
	}
	otto := New()
	if setup != nil {
		setup(otto)
	}
	return otto
}

func failSet(name string, value interface{}) Value {
	err := _runTestWithOtto.Otto.Set(name, value)
	Is(err, nil)
	if err != nil {
		Terst().TestingT.FailNow()
	}
	return _runTestWithOtto.Otto.getValue(name)
}

func runTestWithOtto() (*Otto, func(string, ...interface{}) Value) {
	cache := &_runTestWithOtto
	Otto := newOtto("", nil)
	test := func(name string, expect ...interface{}) Value {
		raise := false
		defer func() {
			if caught := recover(); caught != nil {
				if exception, ok := caught.(*_exception); ok {
					caught = exception.eject()
				}
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
			value = Otto.runtime.run(source)
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

func TestError_URIError(t *testing.T) {
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

		[ abc, def ];
	`, "true,false")

	test(`
        var object = [0, 1, 2];
        Object.defineProperty(object, "0", {
            value: 42,
            writable: false,
            enumerable: false,
            configurable: false
        });
        var abc = Object.getOwnPropertyDescriptor(object, "0");
        [ abc.value, abc.writable, abc.enumerable, abc.configurable ];
    `, "42,false,false,false")

	test(`
        var abc = { "xyzzy": 42 };
        var def = Object.defineProperties(abc, "");
        abc === def;
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

func TestOttoCall(t *testing.T) {
	Terst(t)

	otto, _ := runTestWithOtto()
	_, err := otto.Run(`
        var abc = {
            ghi: 1,
            def: function(def){
                var ghi = 0;
                if (this.ghi) {
                    ghi = this.ghi;
                }
                return "def: " + (def + 3.14159 + ghi);
            }
        };
    `)
	Is(err, nil)

	value, err := otto.Call(`abc.def`, nil, 2)
	Is(err, nil)
	Is(value, "def: 6.14159")

	value, err = otto.Call(`abc.def`, "", 2)
	Is(err, nil)
	Is(value, "def: 5.14159")

	// Do not attempt to do a ToValue on a this of nil
	value, err = otto.Call(`jkl.def`, nil, 1, 2, 3)
	IsNot(err, nil)
	Is(value, "undefined")

	value, err = otto.Call(`[ 1, 2, 3, undefined, 4 ].concat`, nil, 5, 6, 7, "abc")
	Is(err, nil)
	Is(value, "1,2,3,,4,5,6,7,abc")
}

func TestOttoCall_new(t *testing.T) {
	Terst(t)

	_, test := runTestWithOtto()

	failSet("abc", func(call FunctionCall) Value {
		value, err := call.Otto.Call(`new Object`, nil, "Nothing happens.")
		Is(err, nil)
		return value
	})
	test(`
        def = abc();
        [ def, def instanceof String ];
    `, "Nothing happens.,true")
}

func TestOttoCall_throw(t *testing.T) {
	Terst(t)

	return

	_, test := runTestWithOtto()

	failSet("abc", func(call FunctionCall) Value {
		if false {
			call.Otto.Call(`throw eval`, nil, "({ def: 3.14159 })")
		}
		call.Otto.Call(`throw Error`, nil, "abcdef")
		return UndefinedValue()
	})
	// TODO try { abc(); } catch (err) { error = err }
	// Possible unrelated error case:
	// If error is not declared beforehand, is later referencing it a ReferenceError?
	// Should the catch { } declare error in the outer scope?
	test(`
        var error;
        try {
            abc();
        }
        catch (err) {
            error = err;
        }
        [ error instanceof Error, error.message, error.def ];
    `, "true,abcdef,")

	failSet("def", func(call FunctionCall) Value {
		call.Otto.Call(`throw new Object`, nil, 3.14159)
		return UndefinedValue()
	})
	test(`
        try {
            def();
        }
        catch (err) {
            error = err;
        }
        [ error instanceof Error, error.message, error.def, typeof error, error, error instanceof Number ];
    `, "false,,,object,3.14159,true")
}

func TestOttoCopy(t *testing.T) {
	Terst(t)

	otto0 := New()
	otto0.Run(`
        var abc = function() {
            return "Xyzzy";
        };

        function def() {
            return abc() + (0 + {});
        }
    `)

	value, err := otto0.Run(`
        def();
    `)
	Is(err, nil)
	Is(value, "Xyzzy0[object Object]")

	otto1 := otto0.Copy()
	value, err = otto1.Run(`
        def();
    `)
	Is(err, nil)
	Is(value, "Xyzzy0[object Object]")

	otto1.Run(`
        abc = function() {
            return 3.14159;
        };
    `)
	value, err = otto1.Run(`
        def();
    `)
	Is(err, nil)
	Is(value, "3.141590[object Object]")

	value, err = otto0.Run(`
        def();
    `)
	Is(err, nil)
	Is(value, "Xyzzy0[object Object]")
}

func TestOttoCall_clone(t *testing.T) {
	Terst(t)

	otto := New().clone()

	{
		Is(otto.runtime.Global.Array.prototype, otto.runtime.Global.FunctionPrototype)
		IsNot(otto.runtime.Global.ArrayPrototype, nil)
		Is(otto.runtime.Global.Array.runtime, otto.runtime)
		Is(otto.runtime.Global.Array.prototype.runtime, otto.runtime)
		Is(otto.runtime.Global.Array.get("prototype")._object().runtime, otto.runtime)
	}

	{
		value, err := otto.Run(`[ 1, 2, 3 ].toString()`)
		Is(err, nil)
		Is(value, "1,2,3")
	}

	{
		value, err := otto.Run(`[ 1, 2, 3 ]`)
		Is(err, nil)
		Is(value, "1,2,3")
		object := value._object()
		IsNot(object, nil)
		Is(object.prototype, otto.runtime.Global.ArrayPrototype)

		value, err = otto.Run(`Array.prototype`)
		Is(err, nil)
		object = value._object()
		Is(object.runtime, otto.runtime)
		IsNot(object, nil)
		Is(object, otto.runtime.Global.ArrayPrototype)
	}

	{
		otto1 := New()
		_, err := otto1.Run(`
            var abc = 1;
            var def = 2;
        `)
		Is(err, nil)

		otto2 := otto1.clone()
		value, err := otto2.Run(`abc += 1; abc;`)
		Is(err, nil)
		Is(value, "2")

		value, err = otto1.Run(`abc += 4; abc;`)
		Is(err, nil)
		Is(value, "5")
	}

	{
		otto1 := New()
		_, err := otto1.Run(`
            var abc = 1;
            var def = function(value) {
                abc += value;
                return abc;
            }
        `)
		Is(err, nil)

		otto2 := otto1.clone()
		value, err := otto2.Run(`def(1)`)
		Is(err, nil)
		Is(value, "2")

		value, err = otto1.Run(`def(4)`)
		Is(err, nil)
		Is(value, "5")
	}

	{
		otto1 := New()
		_, err := otto1.Run(`
            var abc = {
                ghi: 1,
                jkl: function(value) {
                    this.ghi += value;
                    return this.ghi;
                }
            };
            var def = {
                abc: abc
            };
        `)
		Is(err, nil)

		otto2 := otto1.clone()
		value, err := otto2.Run(`def.abc.jkl(1)`)
		Is(err, nil)
		Is(value, "2")

		value, err = otto1.Run(`def.abc.jkl(4)`)
		Is(err, nil)
		Is(value, "5")
	}
}

func Test_objectLength(t *testing.T) {
	Terst(t)

	otto, _ := runTestWithOtto()
	value := failSet("abc", []string{"jkl", "mno"})
	Is(objectLength(value._object()), 2)

	value, _ = otto.Run(`[1, 2, 3]`)
	Is(objectLength(value._object()), 3)

	value, _ = otto.Run(`new String("abcdefghi")`)
	Is(objectLength(value._object()), 9)

	value, _ = otto.Run(`"abcdefghi"`)
	Is(objectLength(value._object()), 0)
}

func BenchmarkNew(b *testing.B) {
	for i := 0; i < b.N; i++ {
		New()
	}
}

func BenchmarkClone(b *testing.B) {
	otto := New()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		otto.clone()
	}
}

func BenchmarkNew_(b *testing.B) {
	for i := 0; i < b.N; i++ {
		otto := New()
		otto.Run(underscore.Source())
	}
}

func BenchmarkClone_(b *testing.B) {
	otto := New()
	otto.Run(underscore.Source())
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		otto.clone()
	}
}
