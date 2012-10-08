package otto

import (
	"math"
	time_ "time"
)

type _globalCallFunction _nativeFunction
type _globalConstructFunction _constructFunction

func (self *_runtime) newGlobalFunction(
	length int,
	callFunction _globalCallFunction,
	constructFunction _globalConstructFunction,
	prototype *_object,
	nameAndValue... interface{}) *_object {
//
	// TODO We're overwriting the prototype of newNativeFunction with this one, 
	// what is going on?
	target := self.newNativeFunction(_nativeFunction(callFunction), length) 
	target.Function.Construct = _constructFunction(constructFunction)
	target.define(_propertyMode(0), "prototype", toValue(prototype))
	nameAndValue = append(
		[]interface{}{
			_functionSignature("builtin"),
			_propertyMode(propertyModeWrite | propertyModeConfigure),
			"constructor", toValue(target),
		},
		nameAndValue...,
	)
	// This actually may be slower than Define
	// Benchmark?
	prototype.define(nameAndValue...)
	return target
}

func (self *_runtime) newGlobalObject(
	class string,
	nameAndValue... interface{}) *_object {
//
	target := self.newClassObject(class)
	nameAndValue = append(
		[]interface{}{
			_functionSignature("builtin"),
			_propertyMode(propertyModeWrite | propertyModeConfigure),
		},
		nameAndValue...,
	)
	// This actually may be slower than Define
	// Benchmark?
	target.define(nameAndValue...)
	return target
}

func builtinDefine(target *_object, nameAndValue... interface{}) {
	nameAndValue = append(
		[]interface{}{
			_functionSignature("builtin"),
			_propertyMode(propertyModeWrite | propertyModeConfigure),
		},
		nameAndValue...,
	)
	target.define(nameAndValue)
}

func newContext() *_runtime {

	self := &_runtime{}

	self._newError = make(map[string] func(Value) *_object)

	self.GlobalEnvironment = self.newObjectEnvironment()
	self.GlobalObject = self.GlobalEnvironment.Object

	self.EnterGlobalExecutionContext()

	{
		ObjectPrototype := self.newObject()
		ObjectPrototype.Prototype = nil
		self.Global.ObjectPrototype = ObjectPrototype
	}

	{
		FunctionPrototype := self.newNativeFunctionObject(func(FunctionCall) Value {
			return UndefinedValue()
		}, 0)
		FunctionPrototype.Prototype = self.Global.ObjectPrototype
		self.Global.FunctionPrototype = FunctionPrototype
	}

	{
		ArrayPrototype := self.newArray([]Value{})
		ArrayPrototype.Prototype = self.Global.ObjectPrototype
		self.Global.ArrayPrototype = ArrayPrototype
	}

	{
		StringPrototype := self.newString(toValue(""))
		StringPrototype.Prototype = self.Global.ObjectPrototype
		self.Global.StringPrototype = StringPrototype
	}

	{
		BooleanPrototype := self.newBoolean(FalseValue())
		BooleanPrototype.Prototype = self.Global.ObjectPrototype
		self.Global.BooleanPrototype = BooleanPrototype
	}

	{
		NumberPrototype := self.newNumber(toValue(0))
		NumberPrototype.Prototype = self.Global.ObjectPrototype
		self.Global.NumberPrototype = NumberPrototype
	}

	{
		DatePrototype := self.newDate(0)
		DatePrototype.Prototype = self.Global.ObjectPrototype
		self.Global.DatePrototype = DatePrototype
	}

	{
		RegExpPrototype := self.newRegExp(UndefinedValue(), UndefinedValue())
		RegExpPrototype.Prototype = self.Global.ObjectPrototype
		self.Global.RegExpPrototype = RegExpPrototype
	}

	{
		ErrorPrototype := self.newErrorObject(UndefinedValue())
		ErrorPrototype.Prototype = self.Global.ObjectPrototype
		self.Global.ErrorPrototype = ErrorPrototype
	}

	self.Global.Object = self.newGlobalFunction(
		1,
		builtinObject,
		builtinNewObject,
		self.Global.ObjectPrototype,
		"valueOf", func(call FunctionCall) Value {
			return toValue(call.thisObject())
		},
		"toString", builtinObject_toString,
		"hasOwnProperty", func(call FunctionCall) Value {
			propertyName := toString(call.Argument(0))
			thisObject := call.thisObject()
			return toValue(thisObject.HasOwnProperty(propertyName))
		},
		"isPrototypeOf", func(call FunctionCall) Value {
			value := call.Argument(0)
			if !value.IsObject() {
				return FalseValue()
			}
			prototype := call.toObject(value).Prototype
			thisObject := call.thisObject()
			for prototype != nil {
				if thisObject == prototype {
					return TrueValue()
				}
				prototype = prototype.Prototype
			}
			return FalseValue()
		},
		"propertyIsEnumerable", func(call FunctionCall) Value {
			propertyName := toString(call.Argument(0))
			thisObject := call.thisObject()
			property := thisObject.GetOwnProperty(propertyName)
			if property != nil && property.CanEnumerate() {
				return TrueValue()
			}
			return FalseValue()
		},
	)

	self.Global.Function = self.newGlobalFunction(
		1,
		builtinFunction,
		builtinNewFunction,
		self.Global.FunctionPrototype,
		"toString", func(FunctionCall) Value {
			return toValue("[function]")
		},
		"apply", 2, builtinFunction_apply,
		"call", 2, builtinFunction_call,
	)

	self.Global.Array = self.newGlobalFunction(
		1,
		builtinArray,
		builtinNewArray,
		self.Global.ArrayPrototype,
		"toString", func(call FunctionCall) Value {
			thisObject := call.thisObject()
			join := thisObject.Get("join")
			if join.isCallable() {
				join := join._object()
				if join.Function.Call.Signature() == "builtin" {
					if stash, isArray := thisObject._propertyStash.(*_arrayStash); isArray {
						return toValue(builtinArray_joinNative(stash.valueArray, ","))
					}
				}
				return join.Call(call.This, call.ArgumentList)
			}
			return builtinObject_toString(call)
		},
		"concat", 1, builtinArray_concat,
		"join", 1, builtinArray_join,
		"splice", 2, builtinArray_splice,
		"shift", 0, builtinArray_shift,
		"pop", 0, builtinArray_pop,
		"push", 1, builtinArray_push,
		"slice", 2, builtinArray_slice,
		"unshift", 1, builtinArray_unshift,
		"reverse", 0, builtinArray_reverse,
		"sort", 0, builtinArray_sort,
	)

	self.Global.String = self.newGlobalFunction(
		1,
		builtinString,
		builtinNewString,
		self.Global.StringPrototype,
		"toString", func(call FunctionCall) Value {
			return *call.thisClassObject("String").Primitive
		},
		"valueOf", func(call FunctionCall) Value {
			return *call.thisClassObject("String").Primitive
		},
		"charAt", 1, builtinString_charAt,
		"charCodeAt", 1, builtinString_charCodeAt,
		"concat", 1, builtinString_concat,
		"indexOf", 1, builtinString_indexOf,
		"lastIndexOf", 1, builtinString_lastIndexOf,
		"match", 1, builtinString_match,
		"replace", 2, builtinString_replace,
		"search", 1, builtinString_search,
		"split", 2, builtinString_split,
		"slice", 2, builtinString_slice,
		"substring", 2, builtinString_substring,
		"toLowerCase", 0, builtinString_toLowerCase,
		"toUpperCase", 0, builtinString_toUpperCase,
	)

	self.Global.Boolean = self.newGlobalFunction(
		1,
		builtinBoolean,
		builtinNewBoolean,
		self.Global.BooleanPrototype,
		"toString", func(call FunctionCall) Value {
			value := call.This
			if !value.IsBoolean() {
				// Will throw a TypeError if ThisObject is not a Boolean
				value = call.thisClassObject("Boolean").PrimitiveValue()
			}
			return toValue(toString(value))
		},
		"valueOf", func(call FunctionCall) Value {
			value := call.This
			if !value.IsBoolean() {
				value = call.thisClassObject("Boolean").PrimitiveValue()
			}
			return value
		},
	)

	self.Global.Number = self.newGlobalFunction(
		1,
		builtinNumber,
		builtinNewNumber,
		self.Global.NumberPrototype,
		"valueOf", func(call FunctionCall) Value {
			return *call.thisClassObject("Number").Primitive
		},
		// TODO toFixed
		// TODO toExponential
		// TODO toPrecision
	)

	self.Global.Number.Define(
		_propertyMode(0),
		"MAX_VALUE", toValue(math.MaxFloat64),
		"MIN_VALUE", toValue(math.SmallestNonzeroFloat64),
		"NaN", NaNValue(),
		"NEGATIVE_INFINITY", negativeInfinityValue(),
		"POSITIVE_INFINITY", positiveInfinityValue(),
	)

	self.Global.Math = self.newGlobalObject(
		"Math",
		"max", 2, builtinMath_max,
		"min", 2, builtinMath_min,
		"ceil", 1, builtinMath_ceil,
		"floor", 1, builtinMath_floor,
		"random", 0, builtinMath_random,
	)

	self.Global.Date = self.newGlobalFunction(
		7,
		builtinDate,
		builtinNewDate,
		self.Global.DatePrototype,
		"toString", 0, builtinDate_toString,
		"valueOf", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return date.Value()
		},
		// getTime, ...
		"getTime", 0, builtinDate_getTime,
		"getFullYear", 0, func(call FunctionCall) Value {
			// Will throw a TypeError is ThisObject is nil or
			// does not have Class of "Date"
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(date.Time().Local().Year())
		},
		"getUTCFullYear", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(date.Time().Year())
		},
		"getMonth", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(dateFromGoMonth(date.Time().Local().Month()))
		},
		"getUTCMonth", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(dateFromGoMonth(date.Time().Month()))
		},
		"getDate", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(date.Time().Local().Day())
		},
		"getUTCDate", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(date.Time().Day())
		},
		// Actually day of the week
		"getDay", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(dateFromGoDay(date.Time().Local().Weekday()))
		},
		"getUTCDay", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(dateFromGoDay(date.Time().Weekday()))
		},
		"getHours", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(date.Time().Local().Hour())
		},
		"getUTCHours", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(date.Time().Hour())
		},
		"getMinutes", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(date.Time().Local().Minute())
		},
		"getUTCMinutes", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(date.Time().Minute())
		},
		"getSeconds", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(date.Time().Local().Second())
		},
		"getUTCSeconds", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(date.Time().Second())
		},
		"getMilliseconds", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(date.Time().Local().Nanosecond() / (100 * 100 * 100))
		},
		"getUTCMilliseconds", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			return toValue(date.Time().Nanosecond() / (100 * 100 * 100))
		},
		"getTimezoneOffset", 0, func(call FunctionCall) Value {
			date := dateObjectOf(call.thisObject())
			if date.isNaN {
				return NaNValue()
			}
			timeLocal := date.Time().Local()
			// Is this kosher?
			timeLocalAsUTC := time_.Date(
				timeLocal.Year(),
				timeLocal.Month(),
				timeLocal.Day(),
				timeLocal.Hour(),
				timeLocal.Minute(),
				timeLocal.Second(),
				timeLocal.Nanosecond(),
				time_.UTC,
			)
			return toValue(date.Time().Sub(timeLocalAsUTC).Seconds() / 60)
		},
		// setTime, ...
		"setTime", 1, builtinDate_setTime,
		"setMilliseconds", 1, func(call FunctionCall) Value {
			date, ecmaTime := _builtinDate_set(call, 1, true)
			if ecmaTime == nil {
				return NaNValue()
			}
			ecmaTime.millisecond = int(toInteger(call.Argument(0)))
			date.SetTime(ecmaTime.goTime())
			return date.Value()
		},
		"setUTCMilliseconds", 1, func(call FunctionCall) Value {
			date, ecmaTime := _builtinDate_set(call, 1, false)
			if ecmaTime == nil {
				return NaNValue()
			}
			ecmaTime.millisecond = int(toInteger(call.Argument(0)))
			date.SetTime(ecmaTime.goTime())
			return date.Value()
		},
		"setSeconds", 1, func(call FunctionCall) Value {
			date, ecmaTime := _builtinDate_set(call, 1, true)
			if ecmaTime == nil {
				return NaNValue()
			}
			ecmaTime.second = int(toInteger(call.Argument(0)))
			date.SetTime(ecmaTime.goTime())
			return date.Value()
		},
		"setUTCSeconds", 1, func(call FunctionCall) Value {
			date, ecmaTime := _builtinDate_set(call, 1, false)
			if ecmaTime == nil {
				return NaNValue()
			}
			ecmaTime.second = int(toInteger(call.Argument(0)))
			date.SetTime(ecmaTime.goTime())
			return date.Value()
		},
		"setMinutes", 1, func(call FunctionCall) Value {
			date, ecmaTime := _builtinDate_set(call, 1, true)
			if ecmaTime == nil {
				return NaNValue()
			}
			ecmaTime.minute = int(toInteger(call.Argument(0)))
			date.SetTime(ecmaTime.goTime())
			return date.Value()
		},
		"setUTCMinutes", 1, func(call FunctionCall) Value {
			date, ecmaTime := _builtinDate_set(call, 1, false)
			if ecmaTime == nil {
				return NaNValue()
			}
			ecmaTime.minute = int(toInteger(call.Argument(0)))
			date.SetTime(ecmaTime.goTime())
			return date.Value()
		},
		"setHours", 1, func(call FunctionCall) Value {
			date, ecmaTime := _builtinDate_set(call, 1, true)
			if ecmaTime == nil {
				return NaNValue()
			}
			ecmaTime.hour = int(toInteger(call.Argument(0)))
			date.SetTime(ecmaTime.goTime())
			return date.Value()
		},
		"setUTCHours", 1, func(call FunctionCall) Value {
			date, ecmaTime := _builtinDate_set(call, 1, false)
			if ecmaTime == nil {
				return NaNValue()
			}
			ecmaTime.hour = int(toInteger(call.Argument(0)))
			date.SetTime(ecmaTime.goTime())
			return date.Value()
		},
		"setDate", 1, func(call FunctionCall) Value {
			date, ecmaTime := _builtinDate_set(call, 1, true)
			if ecmaTime == nil {
				return NaNValue()
			}
			ecmaTime.day = int(toInteger(call.Argument(0)))
			date.SetTime(ecmaTime.goTime())
			return date.Value()
		},
		"setUTCDate", 1, func(call FunctionCall) Value {
			date, ecmaTime := _builtinDate_set(call, 1, false)
			if ecmaTime == nil {
				return NaNValue()
			}
			ecmaTime.day = int(toInteger(call.Argument(0)))
			date.SetTime(ecmaTime.goTime())
			return date.Value()
		},
		"setMonth", 1, func(call FunctionCall) Value {
			date, ecmaTime := _builtinDate_set(call, 1, true)
			if ecmaTime == nil {
				return NaNValue()
			}
			ecmaTime.month = int(toInteger(call.Argument(0)))
			date.SetTime(ecmaTime.goTime())
			return date.Value()
		},
		"setUTCMonth", 1, func(call FunctionCall) Value {
			date, ecmaTime := _builtinDate_set(call, 1, false)
			if ecmaTime == nil {
				return NaNValue()
			}
			ecmaTime.month = int(toInteger(call.Argument(0)))
			date.SetTime(ecmaTime.goTime())
			return date.Value()
		},
		"setFullYear", 1, func(call FunctionCall) Value {
			date, ecmaTime := _builtinDate_set(call, 1, true)
			if ecmaTime == nil {
				return NaNValue()
			}
			ecmaTime.year = int(toInteger(call.Argument(0)))
			date.SetTime(ecmaTime.goTime())
			return date.Value()
		},
		"setUTCFullYear", 1, func(call FunctionCall) Value {
			date, ecmaTime := _builtinDate_set(call, 1, false)
			if ecmaTime == nil {
				return NaNValue()
			}
			ecmaTime.year = int(toInteger(call.Argument(0)))
			date.SetTime(ecmaTime.goTime())
			return date.Value()
		},
		// toUTCString
		// toISOString
		// toJSONString
		// toJSON
	)

	self.Global.RegExp = self.newGlobalFunction(
		2,
		builtinRegExp,
		builtinNewRegExp,
		self.Global.RegExpPrototype,
		"toString", 0, builtinRegExp_toString,
		"exec", 1, builtinRegExp_exec,
		"test", 1, builtinRegExp_test,
	)

	self.Global.Error = self.newGlobalFunction(
		1,
		builtinError,
		builtinNewError,
		self.Global.ErrorPrototype,
		"name", toValue("Error"),
		"toString", 0, builtinError_toString,
	)

	self.GlobalObject.Define(
		"Object", toValue(self.Global.Object),
		"Function", toValue(self.Global.Function),
		"Array", toValue(self.Global.Array),
		"String", toValue(self.Global.String),
		"Boolean", toValue(self.Global.Boolean),
		"Number", toValue(self.Global.Number),
		"Math", toValue(self.Global.Math),
		"RegExp", toValue(self.Global.RegExp),
		"Date", toValue(self.Global.Date),
		"Error", toValue(self.Global.Error),
		// TODO JSON

		// TODO Is _propertyMode(0) compatible with 3?
		// _propertyMode(0),
		"undefined", UndefinedValue(),
		"NaN", NaNValue(),
		"Infinity", positiveInfinityValue(),
		"eval", builtinGlobal_eval,
		"parseInt", builtinGlobal_parseInt,
		"parseFloat", builtinGlobal_parseFloat,
		"isNaN", builtinGlobal_isNaN,
		"isFinite", builtinGlobal_isFinite,
		"decodeURI", builtinGlobal_decodeURI_decodeURIComponent,
		"decodeURIComponent", builtinGlobal_decodeURI_decodeURIComponent,
		"encodeURI", builtinGlobal_encodeURI,
		"encodeURIComponent", builtinGlobal_encodeURIComponent,
	)

	self._newError["EvalError"] = self.defineError("EvalError")
	self._newError["TypeError"] = self.defineError("TypeError")
	self._newError["RangeError"] = self.defineError("RangeError")
	self._newError["ReferenceError"] = self.defineError("ReferenceError")
	self._newError["SyntaxError"] = self.defineError("SyntaxError")
	self._newError["URIError"] = self.defineError("URIError")

	return self
}

func (runtime *_runtime) newBaseObject() *_object {
	self := newObject(runtime, "")
	return self
}

func (runtime *_runtime) newClassObject(class string) *_object {
	return newObject(runtime, class)
}

func (runtime *_runtime) newPrimitiveObject(class string, value Value) *_object {
	self := runtime.newClassObject(class)
	self.Primitive = &value
	return self
}

func (runtime *_runtime) newObject() *_object {
	self := runtime.newClassObject("Object")
	self.Prototype = runtime.Global.ObjectPrototype
	return self
}

func (runtime *_runtime) newArray(valueArray []Value) *_object {
	self := runtime.newArrayObject(valueArray)
	self.Prototype = runtime.Global.ArrayPrototype
	return self
}

func (runtime *_runtime) newString(value Value) *_object {
	self := runtime.newStringObject(value)
	self.Prototype = runtime.Global.StringPrototype
	return self
}

func (runtime *_runtime) newBoolean(value Value) *_object {
	self := runtime.newBooleanObject(value)
	self.Prototype = runtime.Global.BooleanPrototype
	return self
}

func (runtime *_runtime) newNumber(value Value) *_object {
	self := runtime.newNumberObject(value)
	self.Prototype = runtime.Global.NumberPrototype
	return self
}

func (runtime *_runtime) newRegExp(patternValue Value, flagsValue Value) *_object {
	pattern := ""
	if patternValue.IsDefined() {
		pattern = toString(patternValue)
	}
	flags := ""
	if flagsValue.IsDefined() {
		flags = toString(flagsValue)
	}
	return runtime._newRegExp(pattern, flags)
}

func (runtime *_runtime) _newRegExp(pattern string, flags string) *_object {
	self := runtime.newRegExpObject(pattern, flags)
	self.Prototype = runtime.Global.RegExpPrototype
	return self
}

// TODO Should (probably) be one argument, right? This is redundant
func (runtime *_runtime) newDate(epoch float64) *_object {
	self := runtime.newDateObject(epoch)
	self.Prototype = runtime.Global.DatePrototype
	return self
}

func (runtime *_runtime) newError(name string, message Value) *_object {
	var self *_object
	_newError := runtime._newError[name]
	if _newError != nil {
		self = _newError(message)
	} else {
		self = runtime.newErrorObject(message)
		self.Prototype = runtime.Global.ErrorPrototype
		if name != "" {
			self.WriteValue("name", toValue(name), false)
		}
	}
	return self
}

func (runtime *_runtime) newNativeFunction(_nativeFunction _nativeFunction, length int) *_object {
	self := runtime.newNativeFunctionObject(_nativeFunction, length)
	self.Prototype = runtime.Global.FunctionPrototype
	prototype := runtime.newObject()
	self.define(_propertyMode(0), "prototype", toValue(prototype))
	prototype.define(
		_propertyMode(propertyModeWrite | propertyModeConfigure),
		"constructor", toValue(self),
	)
	return self
}

func (runtime *_runtime) newNodeFunction(node *_functionNode, scopeEnvironment _environment) *_object {
	// TODO Implement 13.2 fully
	self := runtime.newNodeFunctionObject(node, scopeEnvironment)
	self.Prototype = runtime.Global.FunctionPrototype
	prototype := runtime.newObject()
	self.define(_propertyMode(0), "prototype", toValue(prototype))
	prototype.define(
		_propertyMode(propertyModeWrite | propertyModeConfigure),
		"constructor", toValue(self),
	)
	return self
}

func (runtime *_runtime) newErrorPrototype(name string) *_object {
	prototype := runtime.newClassObject("Error")
	prototype.WriteValue("name", toValue(name), false)
	prototype.Prototype = runtime.Global.ErrorPrototype
	return prototype
}

func (runtime *_runtime) defineError(name string) func(Value) *_object {
	prototype := runtime.newErrorPrototype(name) // "TypeError"

	errorFunction := func(message Value) *_object {
		error := runtime.newErrorObject(message)
		error.Prototype = prototype
		return error
	}

	runtime.GlobalObject.WriteValue(name, toValue(runtime.newGlobalFunction(
		1,
		// e.g. TypeError( ... )
		func (call FunctionCall) Value { // TypeError( ... )
			return toValue(errorFunction(call.Argument(0)))
		},
		// e.g. new TypeError( ... )
		func (self *_object, _ Value, argumentList []Value) Value {
			return toValue(errorFunction(valueOfArrayIndex(argumentList, 0)))
		},
		prototype,
	)), false)

	return errorFunction
}
