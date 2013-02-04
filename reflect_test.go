package otto

import (
	. "github.com/robertkrimen/terst"
	"math"
	//"os"
	"reflect"
	"testing"
)

type testStruct struct {
	Abc bool
	Def int
	Ghi string
}

func TestReflect(t *testing.T) {
	Terst(t)

	if false {
		// Testing dbgf
		// These should panic
		toValue("Xyzzy").toReflectValue(reflect.Ptr)
		stringToReflectValue("Xyzzy", reflect.Ptr)
	}
}

func Test_reflectStruct(t *testing.T) {
	Terst(t)

	_, test := runTestWithOtto()

	// testStruct
	{
		abc := &testStruct{}
		failSet("abc", abc)

		test(`
            [ abc.Abc, abc.Ghi ]
        `, "false,")

		abc.Abc = true
		abc.Ghi = "Nothing happens."

		test(`
            [ abc.Abc, abc.Ghi ]
        `, "true,Nothing happens.")

		*abc = testStruct{}

		test(`
            [ abc.Abc, abc.Ghi ]
        `, "false,")

		abc.Abc = true
		abc.Ghi = "Xyzzy"
		failSet("abc", abc)

		test(`
            [ abc.Abc, abc.Ghi ]
        `, "true,Xyzzy")

		Is(abc.Abc, true)
		test(`
            abc.Abc = false;
            abc.Def = 451;
            abc.Ghi = "Nothing happens.";
            abc.abc = "Something happens.";
            [ abc.Def, abc.abc ];
        `, "451,Something happens.")
		Is(abc.Abc, false)
		Is(abc.Def, 451)
		Is(abc.Ghi, "Nothing happens.")

		test(`
            delete abc.Def;
            delete abc.abc;
            [ abc.Def, abc.abc ];
        `, "451,")
		Is(abc.Def, 451)
	}
}

func Test_reflectMap(t *testing.T) {
	Terst(t)

	_, test := runTestWithOtto()

	// map[string]string
	{
		abc := map[string]string{
			"Xyzzy": "Nothing happens.",
			"def":   "1",
		}
		failSet("abc", abc)

		test(`
            abc.xyz = "pqr";
            [ abc.Xyzzy, abc.def, abc.ghi ];
        `, "Nothing happens.,1,")

		Is(abc["xyz"], "pqr")
	}

	// map[string]float64
	{
		abc := map[string]float64{
			"Xyzzy": math.Pi,
			"def":   1,
		}
		failSet("abc", abc)

		test(`
            abc.xyz = "pqr";
            abc.jkl = 10;
            [ abc.Xyzzy, abc.def, abc.ghi ];
        `, "3.141592653589793,1,")

		Is(abc["xyz"], "NaN")
		Is(abc["jkl"], float64(10))
	}

	// map[string]int32
	{
		abc := map[string]int32{
			"Xyzzy": 3,
			"def":   1,
		}
		failSet("abc", abc)

		test(`
            abc.xyz = "pqr";
            abc.jkl = 10;
            [ abc.Xyzzy, abc.def, abc.ghi ];
        `, "3,1,")

		Is(abc["xyz"], 0)
		Is(abc["jkl"], int32(10))

		test(`
            delete abc["Xyzzy"];
        `)

		_, exists := abc["Xyzzy"]
		IsFalse(exists)
		Is(abc["Xyzzy"], 0)
	}

	// map[int32]string
	{
		abc := map[int32]string{
			0: "abc",
			1: "def",
		}
		failSet("abc", abc)

		test(`
            abc[2] = "pqr";
            //abc.jkl = 10;
            abc[3] = 10;
            [ abc[0], abc[1], abc[2], abc[3] ]
        `, "abc,def,pqr,10")

		Is(abc[2], "pqr")
		Is(abc[3], "10")

		test(`
            delete abc[2];
        `)

		_, exists := abc[2]
		IsFalse(exists)
	}
}

func Test_reflectSlice(t *testing.T) {
	Terst(t)

	_, test := runTestWithOtto()

	// []bool
	{
		abc := []bool{
			false,
			true,
			true,
			false,
		}
		failSet("abc", abc)

		test(`
            abc
        `, "false,true,true,false")

		test(`
            abc[0] = true
            abc[abc.length-1] = true
            abc
        `, "true,true,true,true")

		Is(abc, []bool{true, true, true, true})
		Is(abc[len(abc)-1], true)
	}

	// []int32
	{
		abc := make([]int32, 4)
		failSet("abc", abc)

		test(`
            abc
        `, "0,0,0,0")

		test(`
            abc[0] = 4.2
            abc[1] = "42"
            abc[2] = 3.14
            abc
        `, "4,42,3,0")

		Is(abc, []int32{4, 42, 3, 0})

		test(`
            delete abc[1]
            delete abc[2]
        `)
		Is(abc[1], 0)
		Is(abc[2], 0)
	}
}

func Test_reflectArray(t *testing.T) {
	Terst(t)

	_, test := runTestWithOtto()

	// []bool
	{
		abc := [4]bool{
			false,
			true,
			true,
			false,
		}
		failSet("abc", abc)

		test(`
            abc
        `, "false,true,true,false")
		// Unaddressable array

		test(`
            abc[0] = true
            abc[abc.length-1] = true
            abc
        `, "false,true,true,false")
		// Again, unaddressable array

		Is(abc, [4]bool{false, true, true, false})
		Is(abc[len(abc)-1], false)
		// ...
	}

	// []int32
	{
		abc := make([]int32, 4)
		failSet("abc", &abc) // Addressable

		test(`
            abc
        `, "0,0,0,0")

		test(`
            abc[0] = 4.2
            abc[1] = "42"
            abc[2] = 3.14
            abc
        `, "4,42,3,0")

		Is(abc, []int32{4, 42, 3, 0})
	}
}
