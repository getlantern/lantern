package otto

import (
	. "github.com/robertkrimen/terst"
	"testing"
)

func TestFunction_apply(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`String.prototype.substring.length`, "2")
	test(`String.prototype.substring.apply("abc", [1, 11])`, "bc")
}

func TestFunction_call(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`String.prototype.substring.length`, "2")
	test(`String.prototype.substring.call("abc", 1, 11)`, "bc")
}

func TestFunctionArguments(t *testing.T) {
	Terst(t)

	test := runTest()
	// Should not be able to delete arguments
	test(`
        function abc(def, arguments){
            delete def;
            return def;
        }
        abc(1);
    `, "1")

	// Again, should not be able to delete arguments
	test(`
        function abc(def){
            delete def;
            return def;
        }
        abc(1);
    `, "1")
}
