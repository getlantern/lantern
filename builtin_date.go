package otto

import (
	Time "time"
)

// Date

const (
	// TODO Be like V8?
	// builtinDate_goDateTimeLayout = "Mon Jan 2 2006 15:04:05 GMT-0700 (MST)"
	builtinDate_goDateTimeLayout = Time.RFC1123 // "Mon, 02 Jan 2006 15:04:05 MST"
	builtinDate_goDateLayout     = "Mon, 02 Jan 2006"
	builtinDate_goTimeLayout     = "15:04:05 MST"
)

func builtinDate(call FunctionCall) Value {
	date := &_dateObject{}
	if len(call.ArgumentList) == 0 {
		// TODO Should make this prettier
		date.Set(newDateTime([]Value{}, Time.Local))
		return toValue(date.Time().Format(builtinDate_goDateTimeLayout))
	}
	date.Set(newDateTime(call.ArgumentList, Time.Local))
	return toValue(date.Time().Local().Format(builtinDate_goDateTimeLayout))
}

func builtinNewDate(self *_object, _ Value, argumentList []Value) Value {
	return toValue(self.runtime.newDate(newDateTime(argumentList, Time.Local)))
}

func builtinDate_toString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue("Invalid Date")
	}
	return toValue(date.Time().Local().Format(builtinDate_goDateTimeLayout))
}

func builtinDate_toDateString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue("Invalid Date")
	}
	return toValue(date.Time().Local().Format(builtinDate_goDateLayout))
}

func builtinDate_toTimeString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue("Invalid Date")
	}
	return toValue(date.Time().Local().Format(builtinDate_goTimeLayout))
}

func builtinDate_toUTCString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue("Invalid Date")
	}
	return toValue(date.Time().Format(builtinDate_goDateTimeLayout))
}

func builtinDate_toGMTString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue("Invalid Date")
	}
	return toValue(date.Time().Format("Mon, 02 Jan 2006 15:04:05 GMT"))
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

func _builtinDate_beforeSet(call FunctionCall, upToArgument int, timeLocal bool) (*_object, *_dateObject, *_ecmaTime) {
	object := call.thisObject()
	date := dateObjectOf(object)
	if date.isNaN {
		return nil, nil, nil
	}
	// upToArgument is actually the index of the last argument we want to include + 1...
	for index := 0; index < len(call.ArgumentList) && index < upToArgument; index++ {
		value := call.Argument(index)
		if value.IsNaN() {
			object.value = invalidDateObject
		}
	}
	baseTime := date.Time()
	if timeLocal {
		baseTime = baseTime.Local()
	}
	ecmaTime := ecmaTime(baseTime)
	return object, &date, &ecmaTime
}

func builtinDate_parse(call FunctionCall) Value {
	date := toString(call.Argument(0))
	return toValue(dateParse(date))
}

func builtinDate_UTC(call FunctionCall) Value {
	return toValue(newDateTime(call.ArgumentList, Time.UTC))
}

// This is a placeholder
func builtinDate_toLocaleString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue("Invalid Date")
	}
	return toValue(date.Time().Local().Format("2006-01-02 15:04:05"))
}

// This is a placeholder
func builtinDate_toLocaleDateString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue("Invalid Date")
	}
	return toValue(date.Time().Local().Format("2006-01-02"))
}

// This is a placeholder
func builtinDate_toLocaleTimeString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue("Invalid Date")
	}
	return toValue(date.Time().Local().Format("15:04:05"))
}

func builtinDate_valueOf(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return date.Value()
}

func builtinDate_getYear(call FunctionCall) Value {
	// Will throw a TypeError is ThisObject is nil or
	// does not have Class of "Date"
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(date.Time().Local().Year() - 1900)
}

func builtinDate_getFullYear(call FunctionCall) Value {
	// Will throw a TypeError is ThisObject is nil or
	// does not have Class of "Date"
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(date.Time().Local().Year())
}

func builtinDate_getUTCFullYear(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(date.Time().Year())
}

func builtinDate_getMonth(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(dateFromGoMonth(date.Time().Local().Month()))
}

func builtinDate_getUTCMonth(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(dateFromGoMonth(date.Time().Month()))
}

func builtinDate_getDate(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(date.Time().Local().Day())
}

func builtinDate_getUTCDate(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(date.Time().Day())
}

func builtinDate_getDay(call FunctionCall) Value {
	// Actually day of the week
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(dateFromGoDay(date.Time().Local().Weekday()))
}

func builtinDate_getUTCDay(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(dateFromGoDay(date.Time().Weekday()))
}

func builtinDate_getHours(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(date.Time().Local().Hour())
}

func builtinDate_getUTCHours(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(date.Time().Hour())
}

func builtinDate_getMinutes(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(date.Time().Local().Minute())
}

func builtinDate_getUTCMinutes(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(date.Time().Minute())
}

func builtinDate_getSeconds(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(date.Time().Local().Second())
}

func builtinDate_getUTCSeconds(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(date.Time().Second())
}

func builtinDate_getMilliseconds(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(date.Time().Local().Nanosecond() / (100 * 100 * 100))
}

func builtinDate_getUTCMilliseconds(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue(date.Time().Nanosecond() / (100 * 100 * 100))
}

func builtinDate_getTimezoneOffset(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	timeLocal := date.Time().Local()
	// Is this kosher?
	timeLocalAsUTC := Time.Date(
		timeLocal.Year(),
		timeLocal.Month(),
		timeLocal.Day(),
		timeLocal.Hour(),
		timeLocal.Minute(),
		timeLocal.Second(),
		timeLocal.Nanosecond(),
		Time.UTC,
	)
	return toValue(date.Time().Sub(timeLocalAsUTC).Seconds() / 60)
}

func builtinDate_setMilliseconds(call FunctionCall) Value {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.millisecond = int(toInteger(call.Argument(0)))
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setUTCMilliseconds(call FunctionCall) Value {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, false)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.millisecond = int(toInteger(call.Argument(0)))
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setSeconds(call FunctionCall) Value {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.second = int(toInteger(call.Argument(0)))
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setUTCSeconds(call FunctionCall) Value {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, false)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.second = int(toInteger(call.Argument(0)))
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setMinutes(call FunctionCall) Value {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.minute = int(toInteger(call.Argument(0)))
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setUTCMinutes(call FunctionCall) Value {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, false)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.minute = int(toInteger(call.Argument(0)))
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setHours(call FunctionCall) Value {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.hour = int(toInteger(call.Argument(0)))
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setUTCHours(call FunctionCall) Value {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, false)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.hour = int(toInteger(call.Argument(0)))
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setDate(call FunctionCall) Value {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.day = int(toInteger(call.Argument(0)))
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setUTCDate(call FunctionCall) Value {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, false)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.day = int(toInteger(call.Argument(0)))
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setMonth(call FunctionCall) Value {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.month = int(toInteger(call.Argument(0)))
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setUTCMonth(call FunctionCall) Value {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, false)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.month = int(toInteger(call.Argument(0)))
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setYear(call FunctionCall) Value {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	year := int(toInteger(call.Argument(0)))
	if 0 <= year && year <= 99 {
		year += 1900
	}
	ecmaTime.year = year
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setFullYear(call FunctionCall) Value {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.year = int(toInteger(call.Argument(0)))
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setUTCFullYear(call FunctionCall) Value {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, false)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.year = int(toInteger(call.Argument(0)))
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

// toUTCString
// toISOString
// toJSONString
// toJSON
