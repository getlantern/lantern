package otto

import (
	. "./terst"
	"testing"
)

func TestScript(t *testing.T) {
	Terst(t)

	vm := New()

	script, err := vm.Compile("xyzzy", `var abc; if (!abc) abc = 0; abc += 2; abc;`)
	Is(err, nil)

	str := script.String()
	Is(str, "// xyzzy\nvar abc; if (!abc) abc = 0; abc += 2; abc;")

	value, err := vm.Run(script)
	Is(err, nil)
	is(value, 2)

	tmp, err := script.marshalBinary()
	Is(err, nil)
	Is(len(tmp), 1228)

	{
		script := &Script{}
		err = script.unmarshalBinary(tmp)
		Is(err, nil)

		Is(script.String(), str)

		value, err = vm.Run(script)
		Is(err, nil)
		is(value, 4)

		tmp, err = script.marshalBinary()
		Is(err, nil)
		Is(len(tmp), 1228)
	}

	{
		script := &Script{}
		err = script.unmarshalBinary(tmp)
		Is(err, nil)

		Is(script.String(), str)

		value, err := vm.Run(script)
		Is(err, nil)
		is(value, 6)

		tmp, err = script.marshalBinary()
		Is(err, nil)
		Is(len(tmp), 1228)
	}

	{
		version := scriptVersion
		scriptVersion = "bogus"

		script := &Script{}
		err = script.unmarshalBinary(tmp)
		Is(err, "version mismatch")

		Is(script.String(), "// \n")
		Is(script.version, "")
		Is(script.program == nil, true)
		Is(script.filename, "")
		Is(script.src, "")

		scriptVersion = version
	}
}
