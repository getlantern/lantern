package terst

import (
	"fmt"
	"testing"
	. "github.com/robertkrimen/terst"
	"./otto"
)

func Test(t *testing.T) {
	Terst(t)

	Otto := otto.New()
	var result otto.Value

	{
		Otto := otto.New()

		Otto.Run(`
			abc = 2 + 2
			console.log("The value of abc is " + abc)
			// The value of abc is 4
		`)

		value, err := Otto.Get("abc")
		{
			// value is an int64 with a value of 4
			value, _ := value.ToInteger()
			Is(value, int64(4))
		}

		Otto.Set("def", 11)
		Otto.Run(`
			console.log("The value of def is " + def)
			// The value of def is 11
		`)

		Otto.Set("xyzzy", "Nothing happens.")
		Otto.Run(`
			console.log(xyzzy.length) // 16
		`)

		value, _ = Otto.Run("xyzzy.length")
		{
			// value is an int64 with a value of 16
			value, _ := value.ToInteger()
			Is(value, int64(16))
		}

		value, err = Otto.Run("abcdefghijlmnopqrstuvwxyz.length")
		Is(err, "ReferenceError: abcdefghijlmnopqrstuvwxyz is not defined (line 1)")
		if err != nil {
			IsTrue(value.IsUndefined())
			// err = ReferenceError: abcdefghijlmnopqrstuvwxyz is not defined
			// If there is an error, then value.IsUndefined() is true
		}
	}

	{
		Otto.Set("sayHello", func(call otto.FunctionCall) otto.Value {
			fmt.Printf("Hello, %s.\n", call.Argument(0).String())
			return otto.UndefinedValue()
		})

		Otto.Set("twoPlus", func(call otto.FunctionCall) otto.Value {
			right, _ := call.Argument(0).ToInteger()
			result, _ := otto.ToValue(2 + right)
			return result
		})

		result, _ = Otto.Run(`
			// First, say a greeting
			sayHello("Xyzzy") // Hello, Xyzzy.
			sayHello() // Hello, undefined

			result = twoPlus(2.0) // 4
		`)
		Is(result, "4")
	}
}
