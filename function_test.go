package otto

import (
	. "./terst"
	"testing"
)

func TestFunction(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`String.prototype.substring.length`, "2")
	test(`
        var abc = Object.getOwnPropertyDescriptor(Function, "prototype");
        [   [ typeof Function.prototype, typeof Function.prototype.length, Function.prototype.length ],
            [ abc.writable, abc.enumerable, abc.configurable ] ];
    `, "function,number,0,false,false,false")
}

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

	test(`
        function abc(def, ghi, jkl){
            arguments[0] = 3.14;
            arguments[1] = 'Nothing happens';
            arguments[2] = 42;
            if (3.14 === def && 'Nothing happens' === ghi && 42 === jkl)
                return true;
        }
        abc(-1, 4.2, 314);
    `, "true")
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

func TestArguments_defineOwnProperty(t *testing.T) {
	Terst(t)

	test := runTest()

	test(`
        var abc;
        var def = true;
        var ghi = {};
        (function (a, b, c) {
            Object.defineProperty(arguments, "0", {
                value: 42,
                writable: false,
                enumerable: false,
                configurable: false
            });
            Object.defineProperty(arguments, "1", {
                value: 3.14,
                configurable: true,
                enumerable: true
            });
            abc = Object.getOwnPropertyDescriptor(arguments, "0");
            for (var name in arguments) {
                ghi[name] = (ghi[name] || 0) + 1;
                if (name === "0") {
                    def = false;
                }
            }
        }(0, 1, 2));
        [ abc.value, abc.writable, abc.enumerable, abc.configurable, def, ghi["1"] ];
    `, "42,false,false,false,true,1")
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
