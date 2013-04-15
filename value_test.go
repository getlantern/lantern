package otto

import (
	. "./terst"
	"encoding/json"
	"fmt"
	"math"
	"testing"
)

func TestValue(t *testing.T) {
	Terst(t)

	value := UndefinedValue()
	Is(value.IsUndefined(), true)
	Is(value, UndefinedValue())
	Is(value, "undefined")

	Is(toValue(false), "false")
	Is(toValue(1), "1")
	Equal(toValue(1).toFloat(), float64(1))
}

func TestObject(t *testing.T) {
	Terst(t)

	Is(Value{}.isEmpty(), true)
	//Is(newObject().Value(), "[object]")
	//Is(newBooleanObject(false).Value(), "false")
	//Is(newFunctionObject(nil).Value(), "[function]")
	//Is(newNumberObject(1).Value(), "1")
	//Is(newStringObject("Hello, World.").Value(), "Hello, World.")
}

func TestToValue(t *testing.T) {
	Terst(t)
	//Is(toValue(newObjectValue()), "[object]")
}

func TestToBoolean(t *testing.T) {
	Terst(t)
	is := func(left interface{}, right bool) {
		Is(toValue(left).toBoolean(), right)
	}
	is("", false)
	is("xyzzy", true)
	is(1, true)
	is(0, false)
	//is(toValue(newObject()), true)
	is(UndefinedValue(), false)
	is(NullValue(), false)
}

func TestToFloat(t *testing.T) {
	Terst(t)
	is := func(left interface{}, right float64) {
		if math.IsNaN(right) {
			Is(toValue(left).toFloat(), "NaN")
		} else {
			Is(toValue(left).toFloat(), right)
		}
	}
	is("", 0)
	is("xyzzy", math.NaN())
	is("2", 2)
	is(1, 1)
	is(0, 0)
	//is(newObjectValue(), math.NaN())
	IsTrue(math.IsNaN(UndefinedValue().toFloat()))
	is(NullValue(), 0)
}

func TestToObject(t *testing.T) {
	Terst(t)
}

func TestToString(t *testing.T) {
	Terst(t)
	Is("undefined", UndefinedValue().toString())
	Is("null", NullValue().toString())
	Is("true", toValue(true).toString())
	Is("false", toValue(false).toString())

	Is(UndefinedValue(), "undefined")
	Is(NullValue(), "null")
	Is(toValue(true), "true")
	Is(toValue(false), "false")
}

func Test_toInt32(t *testing.T) {
	Terst(t)

	test := []interface{}{
		0, int32(0),
		1, int32(1),
		-2147483649.0, int32(2147483647),
		-4294967297.0, int32(-1),
		-4294967296.0, int32(0),
		-4294967295.0, int32(1),
		math.Inf(+1), int32(0),
		math.Inf(-1), int32(0),
	}
	for index := 0; index < len(test)/2; index++ {
		Like(
			toInt32(toValue(test[index*2])),
			test[index*2+1].(int32),
		)
	}
}

func Test_toUint32(t *testing.T) {
	Terst(t)

	test := []interface{}{
		0, uint32(0),
		1, uint32(1),
		-2147483649.0, uint32(2147483647),
		-4294967297.0, uint32(4294967295),
		-4294967296.0, uint32(0),
		-4294967295.0, uint32(1),
		math.Inf(+1), uint32(0),
		math.Inf(-1), uint32(0),
	}
	for index := 0; index < len(test)/2; index++ {
		Like(
			toUint32(toValue(test[index*2])),
			test[index*2+1].(uint32),
		)
	}
}

func Test_toUint16(t *testing.T) {
	Terst(t)

	test := []interface{}{
		0, uint16(0),
		1, uint16(1),
		-2147483649.0, uint16(65535),
		-4294967297.0, uint16(65535),
		-4294967296.0, uint16(0),
		-4294967295.0, uint16(1),
		math.Inf(+1), uint16(0),
		math.Inf(-1), uint16(0),
	}
	for index := 0; index < len(test)/2; index++ {
		Like(
			toUint16(toValue(test[index*2])),
			test[index*2+1].(uint16),
		)
	}
}

func Test_sameValue(t *testing.T) {
	Terst(t)

	IsFalse(sameValue(positiveZeroValue(), negativeZeroValue()))
	IsTrue(sameValue(positiveZeroValue(), toValue(0)))
	IsTrue(sameValue(NaNValue(), NaNValue()))
	IsFalse(sameValue(NaNValue(), toValue("Nothing happens.")))
}

func TestExport(t *testing.T) {
	Terst(t)

	test := runTest()

	// test exporting a variety of objects
	testObjects := []interface{}{
		true,
		false,
		0,
		7,
		"string",
		[]interface{}{true, false, 0, 7, "string"},
		map[string]interface{}{
			"bool":   true,
			"number": 7.5,
			"string": "string",
			"array": []interface{}{
				true,
				false,
				0,
				7,
				"string"},
			"object": map[string]interface{}{
				"inside": 7}}}

	for _, obj := range testObjects {
		// convert test object to JSON
		bytes, err := json.Marshal(obj)
		Is(err, nil)

		// store that evaluated JSON as variable x
		test("x = " + string(bytes))

		// export x
		exported, err := test(`x`).Export()
		Is(err, nil)

		// convert the exported object to json
		exported_bytes, err := json.Marshal(exported)
		Is(err, nil)

		// compare json from exported value should match origina json
		Is(string(bytes), string(exported_bytes))

	}

	// test exporting undefined
	exported_undefined, err := test(`y`).Export()
	Is(exported_undefined, nil)
	Is(err, fmt.Errorf("undefined"))

	// test object containing undefined, value is omitted from map
	test(`x = { "an_undefined_value": undefined }`)
	exported, err := test(`x`).Export()
	exported_bytes, err := json.Marshal(exported)
	Is(err, nil)
	Is(string(exported_bytes), "{}")
}
