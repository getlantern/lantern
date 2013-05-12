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

func TestObject_isFrozen(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`raise: Object.isFrozen()`, "TypeError")
	test(`Object.isFrozen(Object.preventExtensions({a:1}))`, "false")
	test(`Object.isFrozen({})`, "false")

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
