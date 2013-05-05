package otto

import (
	. "./terst"
	"testing"
)

func Test_panic(t *testing.T) {
	Terst(t)

	test := runTest()

	// Test that property.value is set to something if writable is set
	// to something
	// TODO Not panicking anymore?
	test(`
		var abc = [];
        Object.defineProperty(abc, "0", { writable: false });
        Object.defineProperty(abc, "0", { writable: false });
		"0" in abc;
	`, "true")
	// `, "false") // TODO Should be true, but we're really testing for a panic

	// Test that a regular expression can contain \c0410 (CYRILLIC CAPITAL LETTER A)
	// without panic
	test(`
		var abc = 0x0410;
		var def = String.fromCharCode(abc);
		new RegExp("\\c" + def).exec(def);
	`, "null")

	// Test transforming a transformable regular expression without a panic
	test(`
		new RegExp("\\u0000");
		new RegExp("\\undefined").test("undefined");
	`, "true")
}
