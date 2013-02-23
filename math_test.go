package otto

import (
	. "github.com/robertkrimen/terst"
	"testing"
)

func TestMath_acos(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.acos(NaN)`, "NaN")
	test(`Math.acos(2)`, "NaN")
	test(`Math.acos(-2)`, "NaN")
	test(`1/Math.acos(1)`, "Infinity")

	test(`Math.acos(0.5)`, "1.0471975511965976")
}

func TestMath_ceil(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.ceil(NaN)`, "NaN")
	test(`Math.ceil(+0)`, "0")
	test(`1/Math.ceil(-0)`, "-Infinity")
	test(`Math.ceil(Infinity)`, "Infinity")
	test(`Math.ceil(-Infinity)`, "-Infinity")
	test(`1/Math.ceil(-0.5)`, "-Infinity")

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

func TestMath_pow(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.pow(0, NaN)`, "NaN")
	test(`Math.pow(0, 0)`, "1")
	test(`Math.pow(NaN, 0)`, "1")
	test(`Math.pow(0, -0)`, "1")
	test(`Math.pow(NaN, -0)`, "1")
	test(`Math.pow(NaN, 1)`, "NaN")
	test(`Math.pow(2, Infinity)`, "Infinity")
	test(`1/Math.pow(2, -Infinity)`, "Infinity")
	test(`Math.pow(1, Infinity)`, "NaN")
	test(`Math.pow(1, -Infinity)`, "NaN")
	test(`1/Math.pow(0.1, Infinity)`, "Infinity")
	test(`Math.pow(0.1, -Infinity)`, "Infinity")
	test(`Math.pow(Infinity, 1)`, "Infinity")
	test(`1/Math.pow(Infinity, -1)`, "Infinity")
	test(`Math.pow(-Infinity, 1)`, "-Infinity")
	test(`Math.pow(-Infinity, 2)`, "Infinity")
	test(`1/Math.pow(-Infinity, -1)`, "-Infinity")
	test(`1/Math.pow(-Infinity, -2)`, "Infinity")
	test(`1/Math.pow(0, 1)`, "Infinity")
	test(`Math.pow(0, -1)`, "Infinity")
	test(`1/Math.pow(-0, 1)`, "-Infinity")
	test(`1/Math.pow(-0, 2)`, "Infinity")
	test(`Math.pow(-0, -1)`, "-Infinity")
	test(`Math.pow(-0, -2)`, "Infinity")
	test(`Math.pow(-1, 0.1)`, "NaN")

}
