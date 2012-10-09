package otto

import (
    "testing"
    . "github.com/robertkrimen/terst"
)


func TestSynopsis(t *testing.T) {
	Terst(t)

	Otto := New()

	Otto.Run(`
		abc = 2 + 2
		console.log("The value of abc is " + abc)
		// The value of abc is 4
	`)

	// abc is an int64 with a value of 4
	abc, _ := Otto.Get("abc")
	{
		abc, _ := abc.ToInteger()
		Is(abc, int64(4))
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

	xyzzyLength, _ := Otto.Run("xyzzy.length")
	{
		xyzzyLength, _ := xyzzyLength.ToInteger()
		Is(xyzzyLength, int64(16))
	}

	{
		value, err := Otto.Run("abcdefghijlmnopqrstuvwxyz.length")
		Is(err, "ReferenceError: abcdefghijlmnopqrstuvwxyz is not defined (line 0)")
		if err != nil {
			IsTrue(value.IsUndefined())
		}
	}
}
