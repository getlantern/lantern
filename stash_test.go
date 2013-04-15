package otto

import (
	. "./terst"
	"testing"
)

func TestStash(t *testing.T) {
	Terst(t)

	stash := newObjectStash(true)
	IsTrue(stash.canPut("xyzzy"))

	//stash.define("xyzzy", _defineProperty{
	//    Value: toValue("Nothing happens."),
	//})
	//IsTrue(stash.test("xyzzy"))
	//IsTrue(stash.canPut("xyzzy"))

	//stash.define("xyzzy", _defineProperty{
	//    Value: toValue("Something else happens."),
	//    Write: propertyAttributeFalse,
	//})
	//IsTrue(stash.test("xyzzy"))
	//IsFalse(stash.canPut("xyzzy"))
}
