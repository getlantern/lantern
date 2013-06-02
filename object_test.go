package otto

import (
	. "./terst"
	"testing"
)

func TestObject_(t *testing.T) {
	Terst(t)

	object := newObject(nil, "")
	IsTrue(object != nil)

	object.put("xyzzy", toValue("Nothing happens."), true)
	Is(object.get("xyzzy"), "Nothing happens.")
}

func TestStringObject(t *testing.T) {
	Terst(t)

	object := New().runtime.newStringObject(toValue("xyzzy"))
	Is(object.get("1"), "y")
	Is(object.get("10"), "undefined")
	Is(object.get("2"), "z")
}

func TestObject_getPrototypeOf(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        abc = {};
        def = Object.getPrototypeOf(abc);
        ghi = Object.getPrototypeOf(def);
        [abc,def,ghi,ghi+""];
    `, "[object Object],[object Object],,null")
}

func TestObject_new(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        [ new Object("abc"), new Object(2+2) ];
    `, "abc,4")
}

func TestObject_toLocaleString(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        ({}).toLocaleString();
    `, "[object Object]")

	test(`
        object = {
            toString: function() {
                return "Nothing happens.";
            }
        };
        object.toLocaleString();
    `, "Nothing happens.")
}

func TestObject_isExtensible(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`raise:
        Object.isExtensible();
    `, "TypeError")
	test(`raise:
        Object.isExtensible({});
    `, "true")

	test(`Object.isExtensible.length`, "1")
	test(`Object.isExtensible.prototype`, "undefined")
}

func TestObject_preventExtensions(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`raise:
        Object.preventExtensions()
    `, "TypeError")

	test(`raise:
        var abc = { def: true };
        var ghi = Object.preventExtensions(abc);
        [ ghi.def === true, Object.isExtensible(abc), Object.isExtensible(ghi) ];
    `, "true,false,false")

	test(`
        var abc = new String();
        var def = Object.isExtensible(abc);
        Object.preventExtensions(abc);
        var ghi = false;
        try {
            Object.defineProperty(abc, "0", { value: "~" });
        } catch (err) {
            ghi = err instanceof TypeError;
        }
        [ def, ghi, abc.hasOwnProperty("0"), typeof abc[0] ];
    `, "true,true,false,undefined")

	test(`Object.preventExtensions.length`, "1")
	test(`Object.preventExtensions.prototype`, "undefined")
}

func TestObject_isSealed(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Object.isSealed.length`, "1")
	test(`Object.isSealed.prototype`, "undefined")
}

func TestObject_seal(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`raise: Object.seal()`, "TypeError")
	test(`
		var abc = {a:1,b:1,c:3};
		var sealed = Object.isSealed(abc);
		Object.seal(abc);
		[sealed, Object.isSealed(abc)];
	`, "false,true")
	test(`
		var abc = {a:1,b:1,c:3};
		var sealed = Object.isSealed(abc);
		var caught = false;
		Object.seal(abc);
		abc.b = 5;
		Object.defineProperty(abc, "a", {value:4});
		try {
			Object.defineProperty(abc, "a", {value:42,enumerable:false});
		} catch (e) {
			caught = e instanceof TypeError;
		}
		[sealed, Object.isSealed(abc), caught, abc.a, abc.b];
	`, "false,true,true,4,5")

	test(`Object.seal.length`, "1")
	test(`Object.seal.prototype`, "undefined")
}

func TestObject_isFrozen(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`raise: Object.isFrozen()`, "TypeError")
	test(`Object.isFrozen(Object.preventExtensions({a:1}))`, "false")
	test(`Object.isFrozen({})`, "false")

	test(`
        var abc = {};
        Object.defineProperty(abc, "def", {
            value: "def",
            writable: true,
            configurable: false
        });
        Object.preventExtensions(abc);
        !Object.isFrozen(abc);
    `, "true")

	test(`Object.isFrozen.length`, "1")
	test(`Object.isFrozen.prototype`, "undefined")
}

func TestObject_freeze(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`raise: Object.freeze()`, "TypeError")
	test(`
            var abc = {a:1,b:2,c:3};
            var frozen = Object.isFrozen(abc);
            Object.freeze(abc);
            abc.b = 5;
            [frozen, Object.isFrozen(abc), abc.b];
        `, "false,true,2")

	test(`
            var abc = {a:1,b:2,c:3};
            var frozen = Object.isFrozen(abc);
            var caught = false;
            Object.freeze(abc);
            abc.b = 5;
            try {
                Object.defineProperty(abc, "a", {value:4});
            } catch (e) {
                caught = e instanceof TypeError;
            }
            [frozen, Object.isFrozen(abc), caught, abc.a, abc.b];
        `, "false,true,true,1,2")

	test(`Object.freeze.length`, "1")
	test(`Object.freeze.prototype`, "undefined")
}

func TestObject_defineProperty(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        (function(abc, def, ghi){
            Object.defineProperty(arguments, "0", {
                enumerable: false
            });
            return true;
        })(0, 1, 2);
        `,
		"true",
	)
}

func TestObject_keys(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`Object.keys({ abc:undefined, def:undefined })`, "abc,def")

	test(`
		function abc() {
            this.abc = undefined;
            this.def = undefined;
        }
		Object.keys(new abc())
	`, "abc,def")

	test(`
		function def() {
            this.ghi = undefined;
        }
		def.prototype = new abc();
		Object.keys(new def());
	`, "ghi")

	test(`
		var ghi = Object.create(
            {
                abc: undefined,
                def: undefined
            },
            {
                ghi: { value: undefined, enumerable: true },
                jkl: { value: undefined, enumerable: false }
		    }
        );
		Object.keys(ghi);
	`, "ghi")

	if false {
		test(`
            (function(abc, def, ghi){
                return Object.keys(arguments)
            })(undefined, undefined);
        `, "0,1")
	}
}
