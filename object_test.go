package otto

import (
    "testing"
    . "github.com/robertkrimen/terst"
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
