package otto

import (
	. "./terst"
	"testing"
)

func Test_262(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`raise:
        eval("42 = 42;");
    `, "ReferenceError: Invalid left-hand side in assignment")
}

func Test_issue5(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`'abc' === 'def'`, "false")
	test(`'\t' === '\r'`, "false")
}

func Test_issue13(t *testing.T) {
	Terst(t)

	otto, test := runTestWithOtto()
	value, err := otto.ToValue(map[string]interface{}{
		"string": "Xyzzy",
		"number": 42,
		"array":  []string{"def", "ghi"},
	})
	if err != nil {
		FailNow(err)
	}
	fn, err := otto.Object(`
    (function(value){
        return ""+[value.string, value.number, value.array]
    })
    `)
	if err != nil {
		FailNow(err)
	}
	result, err := fn.Value().Call(fn.Value(), value)
	if err != nil {
		FailNow(err)
	}
	Is(result.toString(), "Xyzzy,42,def,ghi")

	anything := struct {
		Abc interface{}
	}{
		Abc: map[string]interface{}{
			"def": []interface{}{
				[]interface{}{
					"a", "b", "c", "", "d", "e",
				},
				map[string]interface{}{
					"jkl": "Nothing happens.",
				},
			},
			"ghi": -1,
		},
	}
	otto.Set("anything", anything)
	test(`
        [
            anything,
            "~",
            anything.Abc,
            "~",
            anything.Abc.def,
            "~",
            anything.Abc.def[1].jkl,
            "~",
            anything.Abc.ghi,
        ];
        `, "[object Object],~,[object Object],~,a,b,c,,d,e,[object Object],~,Nothing happens.,~,-1",
	)

}

func Test_issue16(t *testing.T) {
	Terst(t)

	otto, test := runTestWithOtto()
	test(`
        var def = {
            "abc": ["abc"],
            "xyz": ["xyz"]
        };
        def.abc.concat(def.xyz);
    `, "abc,xyz")

	otto.Set("ghi", []string{"jkl", "mno"})
	test(`
        def.abc.concat(def.xyz).concat(ghi);
    `, "abc,xyz,jkl,mno")

	test(`
        ghi.concat(def.abc.concat(def.xyz));
    `, "jkl,mno,abc,xyz")

	otto.Set("pqr", []interface{}{"jkl", 42, 3.14159, true})
	test(`
        pqr.concat(ghi, def.abc, def, def.xyz);
    `, "jkl,42,3.14159,true,jkl,mno,abc,[object Object],xyz")

	test(`
        pqr.concat(ghi, def.abc, def, def.xyz).length;
    `, "9")
}

func Test_issue21(t *testing.T) {
	Terst(t)

	otto1 := New()
	otto1.Run(`
        abc = {}
        abc.ghi = "Nothing happens.";
        var jkl = 0;
        abc.def = function() {
            jkl += 1;
            return 1;
        }
    `)
	abc, err := otto1.Get("abc")
	Is(err, nil)

	otto2 := New()
	otto2.Set("cba", abc)
	_, err = otto2.Run(`
        var pqr = 0;
        cba.mno = function() {
            pqr -= 1;
            return 1;
        }
        cba.def();
        cba.def();
        cba.def();
    `)
	Is(err, nil)

	jkl, err := otto1.Get("jkl")
	Is(err, nil)
	Is(jkl, "3")

	_, err = otto1.Run(`
        abc.mno();
        abc.mno();
        abc.mno();
    `)
	Is(err, nil)

	pqr, err := otto2.Get("pqr")
	Is(err, nil)
	Is(pqr, "-3")
}

func Test_issue24(t *testing.T) {
	Terst(t)

	otto, _ := runTestWithOtto()

	{
		otto.Set("abc", []string{"abc", "def", "ghi"})
		value, err := otto.Get("abc")
		Is(err, nil)
		export, _ := value.Export()
		{
			value, valid := export.([]string)
			Is(valid, true)

			Is(value[0], "abc")
			Is(value[2], "ghi")
		}
	}

	{
		otto.Set("abc", [...]string{"abc", "def", "ghi"})
		value, err := otto.Get("abc")
		Is(err, nil)
		export, _ := value.Export()
		{
			value, valid := export.([3]string)
			Is(valid, true)

			Is(value[0], "abc")
			Is(value[2], "ghi")
		}
	}

	{
		otto.Set("abc", &[...]string{"abc", "def", "ghi"})
		value, err := otto.Get("abc")
		Is(err, nil)
		export, _ := value.Export()
		{
			value, valid := export.(*[3]string)
			Is(valid, true)

			Is(value[0], "abc")
			Is(value[2], "ghi")
		}
	}

	{
		otto.Set("abc", map[int]string{0: "abc", 1: "def", 2: "ghi"})
		value, err := otto.Get("abc")
		Is(err, nil)
		export, _ := value.Export()
		{
			value, valid := export.(map[int]string)
			Is(valid, true)

			Is(value[0], "abc")
			Is(value[2], "ghi")
		}
	}

	{
		otto.Set("abc", testStruct{Abc: true, Ghi: "Nothing happens."})
		value, err := otto.Get("abc")
		Is(err, nil)
		export, _ := value.Export()
		{
			value, valid := export.(testStruct)
			Is(valid, true)

			Is(value.Abc, true)
			Is(value.Ghi, "Nothing happens.")
		}
	}

	{
		otto.Set("abc", &testStruct{Abc: true, Ghi: "Nothing happens."})
		value, err := otto.Get("abc")
		Is(err, nil)
		export, _ := value.Export()
		{
			value, valid := export.(*testStruct)
			Is(valid, true)

			Is(value.Abc, true)
			Is(value.Ghi, "Nothing happens.")
		}
	}
}

func Test_issue39(t *testing.T) {
	Terst(t)
	test := runTest()

	test(`
		var a = 0, b = [], x = function() {
			if (a < 10) return ++a;
			return undefined;
		}
		for (var i; (i = x());) b.push(i);
		b
	`, "1,2,3,4,5,6,7,8,9,10")

	test(`
		var a = ["foo", "bar", "baz", "qux"];
		var b = [];
		for (var x; (x = a.shift());) {
			b.push(x);
		}
		b;
	`, "foo,bar,baz,qux")
}
