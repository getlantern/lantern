package otto

import (
    "testing"
    . "github.com/robertkrimen/terst"
)

func TestStash(t *testing.T) {
    Terst(t)

	stash := newPropertyStash(true)
	IsTrue(stash.CanWrite("xyzzy"))

	stash.Define("xyzzy", _defineProperty{
		Value: toValue("Nothing happens."),
	})
	IsTrue(stash.CanRead("xyzzy"))
	IsTrue(stash.CanWrite("xyzzy"))

	stash.Define("xyzzy", _defineProperty{
		Value: toValue("Something else happens."),
		Write: propertyAttributeFalse,
	})
	IsTrue(stash.CanRead("xyzzy"))
	IsFalse(stash.CanWrite("xyzzy"))
}
