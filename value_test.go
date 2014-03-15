package otto

import (
	. "./terst"
	"encoding/json"
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

type intAlias int

func TestToValue(t *testing.T) {
	Terst(t)

	otto, _ := runTestWithOtto()

	value, _ := otto.ToValue(nil)
	Is(value, "undefined")

	value, _ = otto.ToValue((*byte)(nil))
	Is(value, "undefined")

	value, _ = otto.ToValue(intAlias(5))
	Is(value, "5")

	{
		tmp := new(int)

		value, _ = otto.ToValue(&tmp)
		Is(value, "0")

		*tmp = 1

		value, _ = otto.ToValue(&tmp)
		Is(value, "1")

		tmp = nil

		value, _ = otto.ToValue(&tmp)
		Is(value, "undefined")
	}

	{
		tmp0 := new(int)
		tmp1 := &tmp0
		tmp2 := &tmp1

		value, _ = otto.ToValue(&tmp2)
		Is(value, "0")

		*tmp0 = 1

		value, _ = otto.ToValue(&tmp2)
		Is(value, "1")

		tmp0 = nil

		value, _ = otto.ToValue(&tmp2)
		Is(value, "undefined")
	}
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

	Is(test(`null;`).export(), nil)
	Is(test(`undefined;`).export(), nil)
	Is(test(`true;`).export(), true)
	Is(test(`false;`).export(), false)
	Is(test(`0;`).export(), 0)
	Is(test(`3.1459`).export(), 3.1459)
	Is(test(`"Nothing happens";`).export(), "Nothing happens")
	Is(test(`String.fromCharCode(97,98,99,100,101,102)`).export(), "abcdef")
	{
		value := test(`({ abc: 1, def: true, ghi: undefined });`).export().(map[string]interface{})
		Is(value["abc"], 1)
		Is(value["def"], true)
		_, exists := value["ghi"]
		Is(exists, false)
	}
	{
		value := test(`[ "abc", 1, "def", true, undefined, null ];`).export().([]interface{})
		Is(value[0], "abc")
		Is(value[1], 1)
		Is(value[2], "def")
		Is(value[3], true)
		Is(value[4], nil)
		Is(value[5], nil)
		Is(value[5], interface{}(nil))
	}

	roundtrip := []interface{}{
		true,
		false,
		0,
		3.1459,
		[]interface{}{true, false, 0, 3.1459, "abc"},
		map[string]interface{}{
			"Boolean": true,
			"Number":  3.1459,
			"String":  "abc",
			"Array":   []interface{}{false, 0, "", nil},
			"Object": map[string]interface{}{
				"Boolean": false,
				"Number":  0,
				"String":  "def",
			},
		},
	}

	for _, value := range roundtrip {
		input, err := json.Marshal(value)
		Is(err, nil)

		output, err := json.Marshal(test("(" + string(input) + ");").export())
		Is(err, nil)

		Is(string(input), string(output))
	}

	{
		abc := struct {
			def int
			ghi interface{}
			xyz float32
		}{}
		abc.def = 3
		abc.xyz = 3.1459
		failSet("abc", abc)
		Is(test(`abc;`).export(), abc)
	}
}
