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
