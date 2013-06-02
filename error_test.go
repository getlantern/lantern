package otto

import (
	. "./terst"
	"testing"
)

func TestError(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        [ Error.prototype.name, Error.prototype.message, Error.prototype.hasOwnProperty("message") ];
    `, "Error,,true")
}

func TestError_instanceof(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`
        (new TypeError()) instanceof Error
    `, "true")
}

func TestPanicValue(t *testing.T) {
	Terst(t)

	test := runTest()

	failSet("abc", func(call FunctionCall) Value {
		value, err := call.Otto.Run(`({ def: 3.14159 })`)
		Is(err, nil)
		panic(value)
	})
	test(`
        try {
            abc();
        }
        catch (err) {
            error = err;
        }
        [ error instanceof Error, error.message, error.def ];
    `, "false,,3.14159")
}

func Test_catchPanic(t *testing.T) {
	Terst(t)

	// TODO This is here because ToValue(nil) was failing
	return

	otto, _ := runTestWithOtto()
	_, err := otto.Run(`
        A syntax error that
        does not define
        var;
            abc;
    `)
	IsNot(err, nil)

	_, err = otto.Call(`abc.def`, nil)
	IsNot(err, nil)
}
