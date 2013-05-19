package otto

import (
	. "./terst"
	"testing"
)

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
