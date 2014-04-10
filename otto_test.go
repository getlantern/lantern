package otto

import (
	. "./terst"
	//"github.com/robertkrimen/otto/underscore"
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
		var err error
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
			value, err = Otto.runtime.run(source)
			if err != nil {
				panic(err)
			}
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

func TestFunction__(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        function abc() {
            return 1;
        };
        abc();
    `, "1")
}

func TestIf(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        abc = undefined;
        def = undefined;
        if (true) abc = 1
        else abc = 2;
        if (false) {
            def = 3;
        }
        else def = 4;

        [ abc, def ];
    `, "1,4")

	test(`
		if (1) {
			abc = 1;
		}
		else {
			abc = 0;
		}
        [ abc ];
	`, "1")

	test(`
		if (0) {
			abc = 1;
		}
		else {
			abc = 0;
		}
        [ abc ];
	`)

	test(`
		abc = 0;
		if (0) {
			abc = 1;
		}
        [ abc ];
	`, "0")

	test(`
		abc = 0;
		if (abc) {
			abc = 1;
		}
        [ abc ];
	`, "0")
}

func TestSequence(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        1, 2, 3;
    `, "3")
}

func TestCall(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        [ Math.pow(3, 2) ];
    `, "9")
}

func TestMember(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        abc = [ 0, 1, 2 ];
        def = {
            "abc": 0,
            "def": 1,
            "ghi": 2,
        };
        [ abc[2], def.abc, abc[1], def.def ];
    `, "2,0,1,1")
}

func Test_this(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        [ typeof this ];
    `, "object")
}

func TestWhile(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		limit = 4
		abc = 0
		while (limit) {
			abc = abc + 1
			limit = limit - 1
		}
        abc;
	`, "4")
}

func TestSwitch_break(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		var abc = true;
		var ghi = "Xyzzy";
		while (abc) {
			switch ('def') {
			case 'def':
				break;
			}
			ghi = "Nothing happens.";
			abc = false;
		}
		ghi;
	`, "Nothing happens.")

	test(`
		var abc = true;
		var ghi = "Xyzzy";
		WHILE:
		while (abc) {
			switch ('def') {
			case 'def':
				break WHILE;
			}
			ghi = "Nothing happens."
			abc = false
		}
		ghi;
	`, "Xyzzy")

	test(`
		var ghi = "Xyzzy";
		FOR:
		for (;;) {
			switch ('def') {
			case 'def':
				break FOR;
				ghi = "";
			}
			ghi = "Nothing happens.";
		}
		ghi;
	`, "Xyzzy")

	test(`
		var ghi = "Xyzzy";
		FOR:
		for (var jkl in {}) {
			switch ('def') {
			case 'def':
				break FOR;
				ghi = "Something happens.";
			}
			ghi = "Nothing happens.";
		}
		ghi;
	`, "Xyzzy")

	test(`
		var ghi = "Xyzzy";
		function jkl() {
			switch ('def') {
			case 'def':
				break;
				ghi = "";
			}
			ghi = "Nothing happens.";
		}
		while (abc) {
			jkl();
			abc = false;
			ghi = "Something happens.";
		}
		ghi;
	`, "Something happens.")
}

func TestTryFinally(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        var abc;
		try {
			abc = 1;
		}
		finally {
			abc = 2;
		}
        abc;
	`, "2")

	test(`
		var abc = false, def = 0;
		do {
			def += 1;
			if (def > 100) {
				break;
			}
			try {
				continue;
			}
			finally {
				abc = true;
			}
		}
		while(!abc && def < 10)
		def;
	`, "1")

	test(`
		var abc = false, def = 0, ghi = 0;
		do {
			def += 1;
			if (def > 100) {
				break;
			}
			try {
				throw 0;
			}
			catch (jkl) {
				continue;
			}
			finally {
				abc = true;
				ghi = 11;
			}
			ghi -= 1;
		}
		while(!abc && def < 10)
		ghi;
	`, "11")

	test(`
        var abc = 0, def = 0;
        do {
            try {
                abc += 1;
                throw "ghi";
            }
            finally {
                def = 1;
                continue;
            }   
            def -= 1;
        }
        while (abc < 2)
        [ abc, def ];
    `, "2,1")
}

func TestTryCatch(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		var abc = 1;
		try {
			throw 4;
			abc = -1;
		}
		catch (xyzzy) {
			abc += xyzzy + 1;
		}
        abc;
	`, "6")

	test(`
		abc = 1;
        var def;
		try {
			try {
				throw 4;
				abc = -1;
			}
			catch (xyzzy) {
				abc += xyzzy + 1;
				throw 64;
			}
		}
		catch (xyzzy) {
			def = xyzzy;
			abc = -2;
		}
        [ def, abc ];
	`, "64,-2")
}

func TestWith(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		var def;
		with({ abc: 9 }) {
			def = abc;
		}
		def;
	`, "9")

	test(`
		var def;
		with({ abc: function(){
			return 11;
		} }) {
			def = abc();
		}
		def;
	`, "11")
}

func TestSwitch(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		var abc = 0;
		switch (0) {
		default:
			abc += 1;
		case 1:
			abc += 2;
		case 2:
			abc += 4;
		case 3:
			abc += 8;
		}
        abc;
	`, "15")

	test(`
		abc = 0;
		switch (3) {
		default:
			abc += 1;
		case 1:
			abc += 2;
		case 2:
			abc += 4;
		case 3:
			abc += 8;
		}
        abc;
	`, "8")

	test(`
		abc = 0;
		switch (60) {
		case 1:
			abc += 2;
		case 2:
			abc += 4;
		case 3:
			abc += 8;
		}
        abc;
	`, "0")
}

func TestForIn(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        var abc;
		for (property in { a: 1 }) {
			abc = property;
		}
        abc;
	`, "a")

	test(`
        var ghi;
		for (property in new String("xyzzy")) {
			ghi = property;
		}
        ghi;
	`, "4")
}

func TestFor(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
		var abc = 7;
		for (i = 0; i < 3; i += 1) {
			abc += 1;
		}
        abc;
    `, "10")

	test(`
		abc = 7;
		for (i = 0; i < 3; i += 1) {
			abc += 1;
			if (i == 1) {
				break;
			}
		}
        abc;
	`, "9")

	test(`
		abc = 7;
		for (i = 0; i < 3; i += 1) {
			if (i == 2) {
				continue;
			}
			abc += 1;
		}
        abc;
	`, "9")

	test(`
		abc = 0;
		for (;;) {
			abc += 1;
			if (abc == 3)
				break;
		}
        abc;
	`, "3")

	test(`
		for (abc = 0; ;) {
			abc += 1;
			if (abc == 3)
				break;
		}
        abc;
	`, "3")

	test(`
		for (abc = 0; ; abc += 1) {
			abc += 1;
			if (abc == 3)
				break;
		}
        abc;
	`, "3")
}

func TestLabelled(t *testing.T) {
	Terst(t)

	test := runTest()

	// TODO Add emergency break

	test(`
    xyzzy: for (var abc = 0; abc <= 0; abc++) {
        for (var def = 0; def <= 1; def++) {
            if (def === 0) {
                continue xyzzy;
            } else {
            }
        }
    }
    `)

	test(`
		abc = 0
        def:
		while (true) {
            while (true) {
			    abc = abc + 1
                if (abc > 11) {
                    break def;
                }
            }
		}
        [ abc ];
	`, "12")

	test(`
		abc = 0
        def:
        do {
            do {
			    abc = abc + 1
                if (abc > 11) {
                    break def;
                }
            } while (true)
		} while (true)
        [ abc ];
	`, "12")
}

func TestConditional(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        [ true ? false : true, true ? 1 : 0, false ? 3.14159 : "abc" ];
    `, "false,1,abc")
}

func TestArrayLiteral(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        [ 1, , 3.14159 ];
    `, "1,,3.14159")
}

func TestAssignment(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        var abc = 1;
        abc;
    `, "1")

	test(`
        abc += 2;
        abc;
    `, "3")
}

func TestBinaryOperation(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`0 == 1`, "false")
	test(`1 == "1"`, "true")
	test(`0 === 1`, "false")
	test(`1 === "1"`, "false")
	test(`"1" === "1"`, "true")
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
		var abc = 1;
	`)

	test(`
		eval("abc += 1");
	`, "2")

	test(`
		(function(){
			var abc = 11;
			eval("abc += 1");
			return abc;
		})();
	`, "12")
	test(`abc`, "2")

	test(`
		(function(){
			try {
				eval("var prop = \\u2029;");
				return false;
			} catch (abc) {
                return [ abc instanceof SyntaxError, abc.toString() ];
			}
		})();
    `, "true,SyntaxError: Unexpected token ILLEGAL")

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
                    _eval("\'global\' === abc") === true && // eval (Indirect)
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

	test(`
        abc = {
            'abc': 1,
            'def': false,
            3.14159: NaN,
        };
        abc['abc'];
    `, "1")
	abc, err := Otto.Get("abc")
	Is(err, nil)
	object = abc.Object() // Object abc
	value, err = object.Get("abc")
	Is(err, nil)
	Is(value, "1")
	Is(object.Keys(), []string{"abc", "def", "3.14159"})

	test(`
        abc = [ 0, 1, 2, 3.14159, "abc", , ];
        abc.def = true;
    `)
	abc, err = Otto.Get("abc")
	Is(err, nil)
	object = abc.Object() // Object abc
	Is(object.Keys(), []string{"0", "1", "2", "3", "4", "def"})
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

	// FIXME? (Been broken for a while)
	// Looks like this has been broken for a while... what
	// behavior do we want here?

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

	{
		otto1 := New()
		_, err := otto1.Run(`
            var abc = function() { return "abc"; };
            var def = function() { return "def"; };
        `)
		Is(err, nil)

		otto2 := otto1.clone()
		value, err := otto2.Run(`
            [ abc.toString(), def.toString() ];
        `)
		Is(value, `function() { return "abc"; },function() { return "def"; }`)

		_, err = otto2.Run(`
            var def = function() { return "ghi"; };
        `)
		Is(err, nil)

		value, err = otto1.Run(`
            [ abc.toString(), def.toString() ];
        `)
		Is(value, `function() { return "abc"; },function() { return "def"; }`)

		value, err = otto2.Run(`
            [ abc.toString(), def.toString() ];
        `)
		Is(value, `function() { return "abc"; },function() { return "ghi"; }`)
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

//func BenchmarkNew_(b *testing.B) {
//    for i := 0; i < b.N; i++ {
//        otto := New()
//        otto.Run(underscore.Source())
//    }
//}

//func BenchmarkClone_(b *testing.B) {
//    otto := New()
//    otto.Run(underscore.Source())
//    b.ResetTimer()
//    for i := 0; i < b.N; i++ {
//        otto.clone()
//    }
//}
