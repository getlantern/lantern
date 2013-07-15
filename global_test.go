package otto

import (
	. "./terst"
	"fmt"
	//"net/url"
	"strings"
	"testing"
	//"unicode/utf16"
)

func TestGlobal(t *testing.T) {
	Terst(t)

	Otto, test := runTestWithOtto()
	runtime := Otto.runtime

	{
		//trueValue, falseValue := TrueValue(), FalseValue()

		result := runtime.localGet("Object")._object().Call(UndefinedValue(), []Value{toValue(runtime.newObject())})
		Is(result.IsObject(), true)
		Is(result, "[object Object]")
		Is(result._object().prototype == runtime.Global.ObjectPrototype, true)
		Is(result._object().prototype == runtime.Global.Object.get("prototype")._object(), true)
		Is(runtime.newObject().prototype == runtime.Global.Object.get("prototype")._object(), true)
		Is(result._object().get("toString"), "[function]")
		//Is(result.Object().CallMethod("hasOwnProperty", "hasOwnProperty"), falseValue)
		//Is(result.Object().get("toString").Object().prototype.CallMethod("toString"), "[function]")
		//Is(result.Object().get("toString").Object().get("toString").Object(), "[function]")
		//Is(result.Object().get("toString").Object().get("toString"), "[function]")
		//Is(runtime.localGet("Object").Object().CallMethod("isPrototypeOf", result), falseValue)
		//Is(runtime.localGet("Object").Object().get("prototype").Object().CallMethod("isPrototypeOf", result), trueValue)
		//Is(runtime.localGet("Function").Object().CallMethod("isPrototypeOf", result), falseValue)
		//Is(result.Object().CallMethod("propertyIsEnumerable", "isPrototypeOf"), falseValue)
		//result.Object().WriteValue("xyzzy", toValue("Nothing happens."), false)
		//Is(result.Object().CallMethod("propertyIsEnumerable", "xyzzy"), trueValue)
		//Is(result.Object().get("xyzzy"), "Nothing happens.")

		abc := runtime.newBoolean(TrueValue())
		Is(abc, "true")

		def := runtime.localGet("Boolean")._object().Construct(UndefinedValue(), []Value{})
		Is(def, "false")
	}

	test(`new Number().constructor == Number`, "true")

	test(`this.hasOwnProperty`, "[function]")

	test(`eval.length === 1`, "true")
	test(`eval.prototype === undefined`, "true")
	test(`raise: new eval()`, "TypeError: [function] is not a constructor")

	test(`
        [
            [ delete undefined, undefined ],
            [ delete NaN, NaN ],
            [ delete Infinity, Infinity ],
        ];
    `, "false,,false,NaN,false,Infinity")

	test(`
        Object.getOwnPropertyNames(Function('return this')()).sort();
    `, "Array,Boolean,Date,Error,EvalError,Function,Infinity,JSON,Math,NaN,Number,Object,RangeError,ReferenceError,RegExp,String,SyntaxError,TypeError,URIError,console,decodeURI,decodeURIComponent,encodeURI,encodeURIComponent,escape,eval,isFinite,isNaN,parseFloat,parseInt,undefined,unescape")

	// __defineGetter__,__defineSetter__,__lookupGetter__,__lookupSetter__,constructor,hasOwnProperty,isPrototypeOf,propertyIsEnumerable,toLocaleString,toString,valueOf
	test(`
        Object.getOwnPropertyNames(Object.prototype).sort();
    `, "constructor,hasOwnProperty,isPrototypeOf,propertyIsEnumerable,toLocaleString,toString,valueOf")

	// arguments,caller,length,name,prototype
	test(`
        Object.getOwnPropertyNames(EvalError).sort();
    `, "length,prototype")

	test(`
        var abc = [];
        var def = [EvalError, RangeError, ReferenceError, SyntaxError, TypeError, URIError];
        for (constructor in def) {
            abc.push(def[constructor] === def[constructor].prototype.constructor);
        }
        def = [Array, Boolean, Date, Function, Number, Object, RegExp, String, SyntaxError];
        for (constructor in def) {
            abc.push(def[constructor] === def[constructor].prototype.constructor);
        }
        abc;
    `, "true,true,true,true,true,true,true,true,true,true,true,true,true,true,true")

	test(`
        [ Array.prototype.constructor === Array, Array.constructor === Function ];
    `, "true,true")

	test(`
        [ Number.prototype.constructor === Number, Number.constructor === Function ];
    `, "true,true")

	test(`
        [ Function.prototype.constructor === Function, Function.constructor === Function ];
    `, "true,true")
}

func TestGlobalLength(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`Object.length`, "1")
	test(`Function.length`, "1")
	test(`RegExp.length`, "2")
	test(`Math.length`, "undefined")
}

func TestGlobalError(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`TypeError.length`, "1")
	test(`TypeError()`, "TypeError")
	test(`TypeError("Nothing happens.")`, "TypeError: Nothing happens.")

	test(`URIError.length`, "1")
	test(`URIError()`, "URIError")
	test(`URIError("Nothing happens.")`, "URIError: Nothing happens.")
}

func TestGlobalReadOnly(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`Number.POSITIVE_INFINITY`, "Infinity")
	test(`Number.POSITIVE_INFINITY = 1`, "1")
	test(`Number.POSITIVE_INFINITY`, "Infinity")
}

func Test_isNaN(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`isNaN(0)`, "false")
	test(`isNaN("Xyzzy")`, "true")
	test(`isNaN()`, "true")
	test(`isNaN(NaN)`, "true")
	test(`isNaN(Infinity)`, "false")

	test(`isNaN.length === 1`, "true")
	test(`isNaN.prototype === undefined`, "true")
}

func Test_isFinite(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`isFinite(0)`, "true")
	test(`isFinite("Xyzzy")`, "false")
	test(`isFinite()`, "false")
	test(`isFinite(NaN)`, "false")
	test(`isFinite(Infinity)`, "false")
	test(`isFinite(new Number(451));`, "true")

	test(`isFinite.length === 1`, "true")
	test(`isFinite.prototype === undefined`, "true")
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

	test(`parseInt(" 0x11\n", 16)`, "17")
	test(`parseInt("0x0aXyzzy", 16)`, "10")
	test(`parseInt("0x1", 0)`, "1")
	if false {
		// TODO parseInt("0x10000000000000000000", 16)
		test(`parseInt("0x10000000000000000000", 16)`, "75557863725914323419136")
	}

	test(`parseInt.length === 2`, "true")
	test(`parseInt.prototype === undefined`, "true")
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
	test(`parseFloat("11.1")`, "11.1")

	test(`parseFloat("Xyzzy")`, "NaN")

	test(`parseFloat(" 0x11\n", 16)`, "0")
	test(`parseFloat("0x0a")`, "0")
	test(`parseFloat("0x0aXyzzy")`, "0")
	test(`parseFloat("Infinity")`, "Infinity")
	test(`parseFloat("infinity")`, "NaN")
	test(`parseFloat("0x")`, "0")
	test(`parseFloat("11x")`, "11")
	test(`parseFloat("Infinity1")`, "Infinity")

	test(`parseFloat.length === 1`, "true")
	test(`parseFloat.prototype === undefined`, "true")
}

func Test_encodeURI(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`encodeURI("http://example.com/ Nothing happens.")`, "http://example.com/%20Nothing%20happens.")
	test(`encodeURI("http://example.com/ _^#")`, "http://example.com/%20_%5E#")
	test(`encodeURI(String.fromCharCode("0xE000"))`, "%EE%80%80")
	test(`encodeURI(String.fromCharCode("0xFFFD"))`, "%EF%BF%BD")
	test(`raise: encodeURI(String.fromCharCode("0xDC00"))`, "URIError: URI malformed")

	test(`encodeURI.length === 1`, "true")
	test(`encodeURI.prototype === undefined`, "true")
}

func Test_encodeURIComponent(t *testing.T) {
	Terst(t)

	return
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
	test(`raise: decodeURI("%DF%7F")`, "URIError: URI malformed")
	for _, check := range strings.Fields("+ %3B %2F %3F %3A %40 %26 %3D %2B %24 %2C %23") {
		test(fmt.Sprintf(`decodeURI("%s")`, check), check)
	}

	test(`decodeURI.length === 1`, "true")
	test(`decodeURI.prototype === undefined`, "true")
}

func Test_decodeURIComponent(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`decodeURIComponent(encodeURI("http://example.com/ Nothing happens."))`, "http://example.com/ Nothing happens.")
	test(`decodeURIComponent(encodeURI("http://example.com/ _^#"))`, "http://example.com/ _^#")

	test(`decodeURIComponent.length === 1`, "true")
	test(`decodeURIComponent.prototype === undefined`, "true")

	test(`
        var global = Function('return this')();
        var abc = Object.getOwnPropertyDescriptor(global, "decodeURIComponent");
        [ abc.value === global.decodeURIComponent, abc.writable, abc.enumerable, abc.configurable ];
    `, "true,true,false,true")
}

func TestGlobal_skipEnumeration(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        var found = [];
        for (var test in this) {
            if (false ||
                test === 'NaN' ||
                test === 'undefined' ||
                test === 'Infinity' ||
                false) {
                found.push(test)
            }
        }
        found;
    `, "")

	test(`
        var found = [];
        for (var test in this) {
            if (false ||
                test === 'Object' ||
                test === 'Function' ||
                test === 'String' ||
                test === 'Number' ||
                test === 'Array' ||
                test === 'Boolean' ||
                test === 'Date' ||
                test === 'RegExp' ||
                test === 'Error' ||
                test === 'EvalError' ||
                test === 'RangeError' ||
                test === 'ReferenceError' ||
                test === 'SyntaxError' ||
                test === 'TypeError' ||
                test === 'URIError' ||
                false) {
                found.push(test)
            }
        }
        found;
    `, "")
}
