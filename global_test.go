package otto

import (
	. "github.com/robertkrimen/terst"
	"testing"
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
	test(`parseInt("0x0a", Infinity)`, "10")
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
