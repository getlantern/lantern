package otto

import (
	"math"
	"math/rand"
)

// Math

func builtinMath_acos(call FunctionCall) Value {
	number := toFloat(call.Argument(0))
	return toValue(math.Acos(number))
}

func builtinMath_asin(call FunctionCall) Value {
	number := toFloat(call.Argument(0))
	return toValue(math.Asin(number))
}

func builtinMath_ceil(call FunctionCall) Value {
	number := toFloat(call.Argument(0))
	return toValue(math.Ceil(number))
}

func builtinMath_exp(call FunctionCall) Value {
	number := toFloat(call.Argument(0))
	return toValue(math.Exp(number))
}

func builtinMath_floor(call FunctionCall) Value {
	number := toFloat(call.Argument(0))
	return toValue(math.Floor(number))
}

func builtinMath_max(call FunctionCall) Value {
	switch len(call.ArgumentList) {
	case 0:
		return negativeInfinityValue()
	case 1:
		return toValue(toFloat(call.ArgumentList[0]))
	}
	result := toFloat(call.ArgumentList[0])
	if math.IsNaN(result) {
		return NaNValue()
	}
	for _, value := range call.ArgumentList[1:] {
		value := toFloat(value)
		if math.IsNaN(value) {
			return NaNValue()
		}
		result = math.Max(result, value)
	}
	return toValue(result)
}

func builtinMath_min(call FunctionCall) Value {
	switch len(call.ArgumentList) {
	case 0:
		return positiveInfinityValue()
	case 1:
		return toValue(toFloat(call.ArgumentList[0]))
	}
	result := toFloat(call.ArgumentList[0])
	if math.IsNaN(result) {
		return NaNValue()
	}
	for _, value := range call.ArgumentList[1:] {
		value := toFloat(value)
		if math.IsNaN(value) {
			return NaNValue()
		}
		result = math.Min(result, value)
	}
	return toValue(result)
}

func builtinMath_pow(call FunctionCall) Value {
	// TODO Make sure this works according to the specification (15.8.2.13)
	x := toFloat(call.Argument(0))
	y := toFloat(call.Argument(1))
	if x == 1 && math.IsInf(y, 0) {
		return NaNValue()
	}
	return toValue(math.Pow(x, y))
}

func builtinMath_random(call FunctionCall) Value {
	return toValue(rand.Float64())
}
