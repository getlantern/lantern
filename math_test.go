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

func TestMath_asin(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.asin(NaN)`, "NaN")
	test(`Math.asin(2)`, "NaN")
	test(`Math.asin(-2)`, "NaN")
	test(`1/Math.asin(0)`, "Infinity")
	test(`1/Math.asin(-0)`, "-Infinity")

	test(`Math.asin(0.5)`, "0.5235987755982989")
}

func TestMath_atan(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.atan(NaN)`, "NaN")
	test(`1/Math.atan(0)`, "Infinity")
	test(`1/Math.atan(-0)`, "-Infinity")
	test(`Math.atan(Infinity)`, "1.5707963267948966")
	test(`Math.atan(-Infinity)`, "-1.5707963267948966")

	test(`Math.atan(0.5)`, "0.46364760900080604")
}

func TestMath_atan2(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.atan2()`, "NaN")
	test(`Math.atan2(NaN)`, "NaN")
	test(`Math.atan2(0, NaN)`, "NaN")

	test(`Math.atan2(1, 0)`, "1.5707963267948966")
	test(`Math.atan2(1, -0)`, "1.5707963267948966")

	test(`1/Math.atan2(0, 1)`, "Infinity")
	test(`1/Math.atan2(0, 0)`, "Infinity")
	test(`Math.atan2(0, -0)`, "3.141592653589793")
	test(`Math.atan2(0, -1)`, "3.141592653589793")

	test(`1/Math.atan2(-0, 1)`, "-Infinity")
	test(`1/Math.atan2(-0, 0)`, "-Infinity")
	test(`Math.atan2(-0, -0)`, "-3.141592653589793")
	test(`Math.atan2(-0, -1)`, "-3.141592653589793")

	test(`Math.atan2(-1, 0)`, "-1.5707963267948966")
	test(`Math.atan2(-1, -0)`, "-1.5707963267948966")

	test(`1/Math.atan2(1, Infinity)`, "Infinity")
	test(`Math.atan2(1, -Infinity)`, "3.141592653589793")
	test(`1/Math.atan2(-1, Infinity)`, "-Infinity")
	test(`Math.atan2(-1, -Infinity)`, "-3.141592653589793")

	test(`Math.atan2(Infinity, 1)`, "1.5707963267948966")
	test(`Math.atan2(-Infinity, 1)`, "-1.5707963267948966")

	test(`Math.atan2(Infinity, Infinity)`, "0.7853981633974483")
	test(`Math.atan2(Infinity, -Infinity)`, "2.356194490192345")
	test(`Math.atan2(-Infinity, Infinity)`, "-0.7853981633974483")
	test(`Math.atan2(-Infinity, -Infinity)`, "-2.356194490192345")
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

func TestMath_cos(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.cos(NaN)`, "NaN")
	test(`Math.cos(+0)`, "1")
	test(`Math.cos(-0)`, "1")
	test(`Math.cos(Infinity)`, "NaN")
	test(`Math.cos(-Infinity)`, "NaN")

	test(`Math.cos(0.5)`, "0.8775825618903728")
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

func TestMath_log(t *testing.T) {
	Terst(t)

	test := runTest()
	test(`Math.log(NaN)`, "NaN")
	test(`Math.log(-1)`, "NaN")
	test(`Math.log(+0)`, "-Infinity")
	test(`Math.log(-0)`, "-Infinity")
	test(`1/Math.log(1)`, "Infinity")
	test(`Math.log(Infinity)`, "Infinity")

	test(`Math.log(0.5)`, "-0.6931471805599453")
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
