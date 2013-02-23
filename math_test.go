package otto

import (
	. "github.com/robertkrimen/terst"
	"testing"
)

func TestMath_max(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.max(-11, -1, 0, 1, 2, 3, 11)`, "11")
}

func TestMath_min(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.min(-11, -1, 0, 1, 2, 3, 11)`, "-11")
}

func TestMath_ceil(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.ceil(-11)`, "-11")
	test(`Math.ceil(-0.5)`, "0")
	test(`Math.ceil(1.5)`, "2")
}

func TestMath_exp(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.exp(NaN)`, "NaN")
	test(`Math.exp(+0)`, "1")
	test(`Math.exp(-0)`, "1")
	test(`Math.exp(Infinity)`, "Infinity")
	test(`Math.exp(-Infinity)`, "0")
}

func TestMath_floor(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.floor(NaN)`, "NaN")
	test(`Math.floor(+0)`, "0")
	test(`1/Math.floor(-0)`, "-Infinity")
	test(`Math.floor(Infinity)`, "Infinity")
	test(`Math.floor(-Infinity)`, "-Infinity")

	test(`Math.floor(-11)`, "-11")
	test(`Math.floor(-0.5)`, "-1")
	test(`Math.floor(1.5)`, "1")
}
