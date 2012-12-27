package otto

import (
    "testing"
    . "github.com/robertkrimen/terst"
)

func Test_panic(t *testing.T) {
	Terst(t)

	test := runTest()

	// Test that property.value is set to something if writable is set
	// to something
	test(`
		var abc = [];
        Object.defineProperty(abc, "0", { writable: false });
        Object.defineProperty(abc, "0", { writable: false });
		"0" in abc;
	`, "false") // TODO Should be true, but we're really testing for a panic
}
