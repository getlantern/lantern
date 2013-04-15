package otto

import (
	. "./terst"
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

	// Test typeof of a function argument
	test(`
        function abc(def, ghi, jkl){
            return typeof jkl
        }
        abc("1st", "2nd", "3rd", "4th", "5th");
    `, "string")
}

func TestFunctionDeclarationInFunction(t *testing.T) {
	Terst(t)

	// Function declarations happen AFTER parameter/argument declarations
	// That is, a function declared within a function will shadow/overwrite
	// declared parameters
	test := runTest()
	test(`
        function abc(def){
            return def;
            function def(){
                return 1;
            }
        }
        typeof abc();
    `, "function")
}

func TestFunction_bind(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        abc = function(){
            return "abc";
        };
        def = abc.bind();
        def();
    `, "abc")

	test(`
        abc = function(){
            return arguments[1];
        };
        def = abc.bind(undefined, "abc");
        ghi = abc.bind(undefined, "abc", "ghi");
        [ def(), def("def"), ghi("def") ];
    `, ",def,ghi")
}
