package otto

import (
	"math"
	"math/rand"
)

// Math

func builtinMath_max(call FunctionCall) Value {
	switch len(call.ArgumentList) {
	case 0:
		return negativeInfinityValue()
	case 1:
		return toValue(toFloat(call.ArgumentList[0]))
	default:
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
	return UndefinedValue()
}

func builtinMath_min(call FunctionCall) Value {
	switch len(call.ArgumentList) {
	case 0:
		return positiveInfinityValue()
	case 1:
		return toValue(toFloat(call.ArgumentList[0]))
	default:
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
	return UndefinedValue()
}

func builtinMath_ceil(call FunctionCall) Value {
	number := toFloat(call.Argument(0))
	if math.IsNaN(number) {
		return NaNValue()
	}
	return toValue(math.Ceil(number))
}

func builtinMath_floor(call FunctionCall) Value {
	number := toFloat(call.Argument(0))
	if math.IsNaN(number) {
		return NaNValue()
	}
	return toValue(math.Floor(number))
}

func builtinMath_random(call FunctionCall) Value {
	return toValue(rand.Float64())
}

func builtinMath_pow(call FunctionCall) Value {
	// TODO Make sure this works according to the specification (15.8.2.13)
	return toValue(math.Pow(toFloat(call.Argument(0)), toFloat(call.Argument(1))))
}
