package otto

import (
    "testing"
    . "github.com/robertkrimen/terst"
)

func TestObject_(t *testing.T) {
    Terst(t)

	object := newObject(nil, "")
	IsTrue(object != nil)

	object.Put("xyzzy", toValue("Nothing happens."), true)
	Is(object.Get("xyzzy"), "Nothing happens.")
}

func TestStringObject(t *testing.T) {
    Terst(t)

	object := New().runtime.newStringObject(toValue("xyzzy"))
	Is(object.Get("1"), "y")
	Is(object.Get("10"), "undefined")
	Is(object.Get("2"), "z")
}
