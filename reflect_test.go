package otto

import (
	. "./terst"
	"math"
	"reflect"
	"testing"
)

type testStruct struct {
	Abc bool
	Def int
	Ghi string
	Jkl interface{}
}

func (t *testStruct) FuncPointerReciever() string {
	return "abc"
}

func (t testStruct) FuncNoArgsNoRet() {
	return
}

func (t testStruct) FuncNoArgs() string {
	return "abc"
}

func (t testStruct) FuncNoArgsMultRet() (string, error) {
	return "def", nil
}

func (t testStruct) FuncOneArgs(a string) string {
	return a
}

func (t testStruct) FuncMultArgs(a, b string) string {
	return a + b
}

func (t testStruct) FuncVarArgs(as ...string) int {
	return len(as)
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
			abc.FuncPointerReciever();
		`, "abc")

		test(`
            [ abc.Abc, abc.Ghi ];
        `, "false,")

		abc.Abc = true
		abc.Ghi = "Nothing happens."

		test(`
            [ abc.Abc, abc.Ghi ];
        `, "true,Nothing happens.")

		*abc = testStruct{}

		test(`
            [ abc.Abc, abc.Ghi ];
        `, "false,")

		abc.Abc = true
		abc.Ghi = "Xyzzy"
		failSet("abc", abc)

		test(`
            [ abc.Abc, abc.Ghi ];
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

		test(`
			abc.FuncNoArgsNoRet();
		`, "undefined")
		test(`
			abc.FuncNoArgs();
		`, "abc")
		test(`
			abc.FuncOneArgs("abc");
		`, "abc")
		test(`
			abc.FuncMultArgs("abc", "def");
		`, "abcdef")
		test(`
			abc.FuncVarArgs("abc", "def", "ghi");
		`, "3")

		test(`raise:
            abc.FuncNoArgsMultRet();
        `, "TypeError")
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
            abc;
        `, "false,true,true,false")

		test(`
            abc[0] = true;
            abc[abc.length-1] = true;
            delete abc[2];
            abc;
        `, "true,true,false,true")

		Is(abc, []bool{true, true, false, true})
		Is(abc[len(abc)-1], true)
	}

	// []int32
	{
		abc := make([]int32, 4)
		failSet("abc", abc)

		test(`
            abc;
        `, "0,0,0,0")

		test(`
            abc[0] = 4.2;
            abc[1] = "42";
            abc[2] = 3.14;
            abc;
        `, "4,42,3,0")

		Is(abc, []int32{4, 42, 3, 0})

		test(`
            delete abc[1];
            delete abc[2];
        `)
		Is(abc[1], 0)
		Is(abc[2], 0)
	}
}

func Test_reflectArray(t *testing.T) {
	Terst(t)

	_, test := runTestWithOtto()

	// []bool
	if false {
		abc := [4]bool{
			false,
			true,
			true,
			false,
		}
		failSet("abc", abc)

		test(`
            abc;
        `, "false,true,true,false")
		// Unaddressable array

		test(`
            abc[0] = true;
            abc[abc.length-1] = true;
            abc;
        `, "false,true,true,false")
		// Again, unaddressable array

		Is(abc, [4]bool{false, true, true, false})
		Is(abc[len(abc)-1], false)
		// ...
	}

	// []int32
	if false {
		abc := make([]int32, 4)
		failSet("abc", abc)

		test(`
            abc;
        `, "0,0,0,0")

		test(`
            abc[0] = 4.2;
            abc[1] = "42";
            abc[2] = 3.14;
            abc;
        `, "4,42,3,0")

		Is(abc, []int32{4, 42, 3, 0})
	}

	// []bool
	{
		abc := [4]bool{
			false,
			true,
			true,
			false,
		}
		failSet("abc", &abc)

		test(`
            abc;
        `, "false,true,true,false")

		test(`
            abc[0] = true;
            abc[abc.length-1] = true;
            delete abc[2];
            abc;
        `, "true,true,false,true")

		Is(abc, [4]bool{true, true, false, true})
		Is(abc[len(abc)-1], true)
	}

}

func Test_reflectArray_concat(t *testing.T) {
	Terst(t)

	_, test := runTestWithOtto()
	failSet("ghi", []string{"jkl", "mno"})
	failSet("pqr", []interface{}{"jkl", 42, 3.14159, true})
	test(`
        var def = {
            "abc": ["abc"],
            "xyz": ["xyz"]
        };
        xyz = pqr.concat(ghi, def.abc, def, def.xyz);
        [ xyz, xyz.length ];
    `, "jkl,42,3.14159,true,jkl,mno,abc,[object Object],xyz,9")
}

func Test_reflectMapInterface(t *testing.T) {
	Terst(t)

	_, test := runTestWithOtto()

	{
		abc := map[string]interface{}{
			"Xyzzy": "Nothing happens.",
			"def":   "1",
			"jkl":   "jkl",
		}
		failSet("abc", abc)
		failSet("mno", &testStruct{})

		test(`
            abc.xyz = "pqr";
            abc.ghi = {};
            abc.jkl = 3.14159;
            abc.mno = mno;
            mno.Abc = true;
            mno.Ghi = "Something happens.";
            [ abc.Xyzzy, abc.def, abc.ghi, abc.mno ];
        `, "Nothing happens.,1,[object Object],[object Object]")

		Is(abc["xyz"], "pqr")
		Is(abc["ghi"], "[object Object]")
		Equal(abc["jkl"], float64(3.14159))
		mno, valid := abc["mno"].(*testStruct)
		Is(valid, true)
		Is(mno.Abc, true)
		Is(mno.Ghi, "Something happens.")
	}
}
