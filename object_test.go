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
