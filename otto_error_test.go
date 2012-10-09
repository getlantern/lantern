package otto

import (
    "testing"
    . "github.com/robertkrimen/terst"
)

func TestOttoError(t *testing.T) {
    Terst(t)

	Otto := New()

	_, err := Otto.Run(`throw "Xyzzy"`)
	Is(err, "Xyzzy")

	_, err = Otto.Run(`throw new TypeError()`)
	Is(err, "TypeError")

	_, err = Otto.Run(`throw new TypeError("Nothing happens.")`)
	Is(err, "TypeError: Nothing happens.")

	_, err = ToValue([]byte{})
	Is(err, "TypeError: Unable to convert value: [] ([]uint8)")

	_, err = Otto.Run(`
		(function(){
			return abcdef.length
		})()
	`)
	Is(err, "ReferenceError: abcdef is not defined (line 2)")

}
