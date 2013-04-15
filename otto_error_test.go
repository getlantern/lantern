package otto

import (
	. "./terst"
	"testing"
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
	Is(err, "TypeError: Invalid value (slice): Missing runtime: [] ([]uint8)")

	_, err = Otto.Run(`
		(function(){
			return abcdef.length
		})()
	`)
	Is(err, "ReferenceError: abcdef is not defined (line 3)")

	_, err = Otto.Run(`
	function start() {
	}

	start()

		xyzzy()
	`)
	Is(err, "ReferenceError: xyzzy is not defined (line 7)")

	_, err = Otto.Run(`
		// Just a comment

		xyzzy
	`)
	Is(err, "ReferenceError: xyzzy is not defined (line 4)")

}
