package otto

import (
	"math"
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
		return toValue_string(date.Time().Format(builtinDate_goDateTimeLayout))
	}
	date.Set(newDateTime(call.ArgumentList, Time.Local))
	return toValue_string(date.Time().Local().Format(builtinDate_goDateTimeLayout))
}

func builtinNewDate(self *_object, _ Value, argumentList []Value) Value {
	return toValue_object(self.runtime.newDate(newDateTime(argumentList, Time.Local)))
}

func builtinDate_toString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue_string("Invalid Date")
	}
	return toValue_string(date.Time().Local().Format(builtinDate_goDateTimeLayout))
}

func builtinDate_toDateString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue_string("Invalid Date")
	}
	return toValue_string(date.Time().Local().Format(builtinDate_goDateLayout))
}

func builtinDate_toTimeString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue_string("Invalid Date")
	}
	return toValue_string(date.Time().Local().Format(builtinDate_goTimeLayout))
}

func builtinDate_toUTCString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue_string("Invalid Date")
	}
	return toValue_string(date.Time().Format(builtinDate_goDateTimeLayout))
}

func builtinDate_toISOString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue_string("Invalid Date")
	}
	return toValue_string(date.Time().Format("2006-01-02T15:04:05.000Z"))
}

func builtinDate_toJSON(call FunctionCall) Value {
	object := call.thisObject()
	value := object.DefaultValue(defaultValueHintNumber) // FIXME object.primitiveNumberValue
	{                                                    // FIXME value.isFinite
		value := toFloat(value)
		if math.IsNaN(value) || math.IsInf(value, 0) {
			return NullValue()
		}
	}
	toISOString := object.get("toISOString")
	if !toISOString.isCallable() {
		panic(newTypeError())
	}
	return toISOString.call(toValue_object(object), []Value{})
}

func builtinDate_toGMTString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue_string("Invalid Date")
	}
	return toValue_string(date.Time().Format("Mon, 02 Jan 2006 15:04:05 GMT"))
}

func builtinDate_getTime(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	// We do this (convert away from a float) so the user
	// does not get something back in exponential notation
	return toValue_int64(int64(date.Epoch()))
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

func _builtinDate_beforeSet1(call FunctionCall, timeLocal bool) (*_object, *_dateObject, *_ecmaTime, int64) {
	object, date, ecmaTime := _builtinDate_beforeSet(call, 1, timeLocal)
	if ecmaTime == nil {
		return nil, nil, nil, 0
	}
	integer := toInteger(call.Argument(0))
	if !integer.valid() {
		date.SetNaN()
		object.value = *date
		return nil, nil, nil, 0
	}
	return object, date, ecmaTime, integer.value
}

func builtinDate_parse(call FunctionCall) Value {
	date := toString(call.Argument(0))
	return toValue_float64(dateParse(date))
}

func builtinDate_UTC(call FunctionCall) Value {
	return toValue_float64(newDateTime(call.ArgumentList, Time.UTC))
}

func builtinDate_now(call FunctionCall) Value {
	call.ArgumentList = []Value(nil)
	return builtinDate_UTC(call)
}

// This is a placeholder
func builtinDate_toLocaleString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue_string("Invalid Date")
	}
	return toValue_string(date.Time().Local().Format("2006-01-02 15:04:05"))
}

// This is a placeholder
func builtinDate_toLocaleDateString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue_string("Invalid Date")
	}
	return toValue_string(date.Time().Local().Format("2006-01-02"))
}

// This is a placeholder
func builtinDate_toLocaleTimeString(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return toValue_string("Invalid Date")
	}
	return toValue_string(date.Time().Local().Format("15:04:05"))
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
	return toValue_int(date.Time().Local().Year() - 1900)
}

func builtinDate_getFullYear(call FunctionCall) Value {
	// Will throw a TypeError is ThisObject is nil or
	// does not have Class of "Date"
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(date.Time().Local().Year())
}

func builtinDate_getUTCFullYear(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(date.Time().Year())
}

func builtinDate_getMonth(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(dateFromGoMonth(date.Time().Local().Month()))
}

func builtinDate_getUTCMonth(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(dateFromGoMonth(date.Time().Month()))
}

func builtinDate_getDate(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(date.Time().Local().Day())
}

func builtinDate_getUTCDate(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(date.Time().Day())
}

func builtinDate_getDay(call FunctionCall) Value {
	// Actually day of the week
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(dateFromGoDay(date.Time().Local().Weekday()))
}

func builtinDate_getUTCDay(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(dateFromGoDay(date.Time().Weekday()))
}

func builtinDate_getHours(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(date.Time().Local().Hour())
}

func builtinDate_getUTCHours(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(date.Time().Hour())
}

func builtinDate_getMinutes(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(date.Time().Local().Minute())
}

func builtinDate_getUTCMinutes(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(date.Time().Minute())
}

func builtinDate_getSeconds(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(date.Time().Local().Second())
}

func builtinDate_getUTCSeconds(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(date.Time().Second())
}

func builtinDate_getMilliseconds(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(date.Time().Local().Nanosecond() / (100 * 100 * 100))
}

func builtinDate_getUTCMilliseconds(call FunctionCall) Value {
	date := dateObjectOf(call.thisObject())
	if date.isNaN {
		return NaNValue()
	}
	return toValue_int(date.Time().Nanosecond() / (100 * 100 * 100))
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
	return toValue_float64(date.Time().Sub(timeLocalAsUTC).Seconds() / 60)
}

func builtinDate_setMilliseconds(call FunctionCall) Value {
	object, date, ecmaTime, value := _builtinDate_beforeSet1(call, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.millisecond = int(value)
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setUTCMilliseconds(call FunctionCall) Value {
	object, date, ecmaTime, value := _builtinDate_beforeSet1(call, false)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.millisecond = int(value)
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setSeconds(call FunctionCall) Value {
	object, date, ecmaTime, value := _builtinDate_beforeSet1(call, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.second = int(value)
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setUTCSeconds(call FunctionCall) Value {
	object, date, ecmaTime, value := _builtinDate_beforeSet1(call, false)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.second = int(value)
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setMinutes(call FunctionCall) Value {
	object, date, ecmaTime, value := _builtinDate_beforeSet1(call, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.minute = int(value)
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setUTCMinutes(call FunctionCall) Value {
	object, date, ecmaTime, value := _builtinDate_beforeSet1(call, false)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.minute = int(value)
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setHours(call FunctionCall) Value {
	object, date, ecmaTime, value := _builtinDate_beforeSet1(call, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.hour = int(value)
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setUTCHours(call FunctionCall) Value {
	object, date, ecmaTime, value := _builtinDate_beforeSet1(call, false)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.hour = int(value)
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setDate(call FunctionCall) Value {
	object, date, ecmaTime, value := _builtinDate_beforeSet1(call, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.day = int(value)
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setUTCDate(call FunctionCall) Value {
	object, date, ecmaTime, value := _builtinDate_beforeSet1(call, false)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.day = int(value)
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setMonth(call FunctionCall) Value {
	object, date, ecmaTime, value := _builtinDate_beforeSet1(call, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.month = int(value)
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setUTCMonth(call FunctionCall) Value {
	object, date, ecmaTime, value := _builtinDate_beforeSet1(call, false)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.month = int(value)
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setYear(call FunctionCall) Value {
	object, date, ecmaTime, value := _builtinDate_beforeSet1(call, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	year := int(value)
	if 0 <= year && year <= 99 {
		year += 1900
	}
	ecmaTime.year = year
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setFullYear(call FunctionCall) Value {
	object, date, ecmaTime, value := _builtinDate_beforeSet1(call, true)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.year = int(value)
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

func builtinDate_setUTCFullYear(call FunctionCall) Value {
	object, date, ecmaTime, value := _builtinDate_beforeSet1(call, false)
	if ecmaTime == nil {
		return NaNValue()
	}
	ecmaTime.year = int(value)
	date.SetTime(ecmaTime.goTime())
	object.value = *date
	return date.Value()
}

// toUTCString
// toISOString
// toJSONString
// toJSON
