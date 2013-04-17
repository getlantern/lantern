package otto

import (
	time_ "time"
)

// Date

func builtinDate(call FunctionCall) Value {
	return toValue(call.runtime.newDate(newDateTime(call.ArgumentList)))
}

func builtinNewDate(self *_object, _ Value, argumentList []Value) Value {
	return toValue(self.runtime.newDate(newDateTime(argumentList)))
}

func builtinDate_toString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue("Invalid Date")
	}
	return toValue(date.Time().Local().Format(time_.RFC1123))
}

func builtinDate_toUTCString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue("Invalid Date")
	}
	return toValue(date.Time().Format(time_.RFC1123))
}

func builtinDate_getTime(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	// We do this (convert away from a float) so the user
	// does not get something back in exponential notation
	return toValue(int64(date.Epoch()))
}

func builtinDate_setTime(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	date.Set(toFloat(call.Argument(0)))
	return date.Value()
}

func _builtinDate_set(call FunctionCall, argumentCap int, dateLocal bool) (*_dateObject, *_ecmaTime) {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return nil, nil
	}
	for index := 0; index < len(call.ArgumentList) && index < argumentCap; index++ {
		value := call.Argument(index)
		if value.IsNaN() {
			date.SetNaN()
			return date, nil
		}
	}
	baseTime := date.Time()
	if dateLocal {
		baseTime = baseTime.Local()
	}
	ecmaTime := ecmaTime(baseTime)
	return date, &ecmaTime
}

func builtinDate_parse(call FunctionCall) Value {
	date := toString(call.Argument(0))
	return toValue(dateParse(date))
}

func builtinDate_UTC(call FunctionCall) Value {
	return toValue(newDateTime(call.ArgumentList))
}
