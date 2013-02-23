package otto

import (
	"math"
	time_ "time"
)

type _globalCallFunction _nativeFunction
type _globalConstructFunction _constructFunction

func (self *_runtime) newGlobalFunction(
	length int,
	name string, callFunction _globalCallFunction,
	constructFunction _globalConstructFunction,
	prototype *_object,
	definition ...interface{}) *_object {

	// TODO We're overwriting the prototype of newNativeFunction with this one, 
	// what is going on?
	functionObject := self.newNativeFunction(_nativeFunction(callFunction), length, "native"+name)
	functionObject._Function.Construct = _constructFunction(constructFunction)
	functionObject.stash.set("prototype", toValue(prototype), _propertyMode(0))

	prototype.write(append([]interface{}{
		_functionSignature("builtin"),
		_propertyMode(0101), // Write | Configure
		"constructor", toValue(functionObject),
	},
		definition...,
	)...)

	return functionObject
}

func (self *_runtime) newGlobalObject(
	class string,
	nameAndValue ...interface{}) *_object {

	target := self.newClassObject(class)
	nameAndValue = append(
		[]interface{}{
			_functionSignature("builtin"),
			_propertyMode(0101), // Write | Configure
		},
		nameAndValue...,
	)
	// This actually may be slower than Define
	// Benchmark?
	target.write(nameAndValue...)
	return target
}

func builtinDefine(target *_object, nameAndValue ...interface{}) {
	nameAndValue = append(
		[]interface{}{
			_functionSignature("builtin"),
			_propertyMode(0101), // Write | Configure
		},
		nameAndValue...,
	)
	target.write(nameAndValue)
}

func newContext() *_runtime {

	self := &_runtime{}

	self._newError = make(map[string]func(Value) *_object)

	self.GlobalEnvironment = self.newObjectEnvironment(nil, nil)
	self.GlobalObject = self.GlobalEnvironment.Object

	self.EnterGlobalExecutionContext()

	{
		ObjectPrototype := self.newObject()
		ObjectPrototype.prototype = nil
		self.Global.ObjectPrototype = ObjectPrototype
	}

	{
		FunctionPrototype := self.newNativeFunctionObject(func(FunctionCall) Value {
			return UndefinedValue()
		}, 0, "nativeFunction_")
		FunctionPrototype.prototype = self.Global.ObjectPrototype
		self.Global.FunctionPrototype = FunctionPrototype
	}

	{
		ArrayPrototype := self.newArray([]Value{})
		ArrayPrototype.prototype = self.Global.ObjectPrototype
		self.Global.ArrayPrototype = ArrayPrototype
	}

	{
		StringPrototype := self.newString(toValue(""))
		StringPrototype.prototype = self.Global.ObjectPrototype
		self.Global.StringPrototype = StringPrototype
	}

	{
		BooleanPrototype := self.newBoolean(FalseValue())
		BooleanPrototype.prototype = self.Global.ObjectPrototype
		self.Global.BooleanPrototype = BooleanPrototype
	}

	{
		NumberPrototype := self.newNumber(toValue(0))
		NumberPrototype.prototype = self.Global.ObjectPrototype
		self.Global.NumberPrototype = NumberPrototype
	}

	{
		DatePrototype := self.newDate(0)
		DatePrototype.prototype = self.Global.ObjectPrototype
		self.Global.DatePrototype = DatePrototype
	}

	{
		RegExpPrototype := self.newRegExp(UndefinedValue(), UndefinedValue())
		RegExpPrototype.prototype = self.Global.ObjectPrototype
		self.Global.RegExpPrototype = RegExpPrototype
	}

	{
		ErrorPrototype := self.newErrorObject(UndefinedValue())
		ErrorPrototype.prototype = self.Global.ObjectPrototype
		self.Global.ErrorPrototype = ErrorPrototype
	}

	self.Global.Object = self.newGlobalFunction(
		1,
		"Object", builtinObject,
		builtinNewObject,
		self.Global.ObjectPrototype,
		"valueOf", func(call FunctionCall) Value {
			return toValue(call.thisObject())
		},
		"toString", builtinObject_toString,
		"hasOwnProperty", func(call FunctionCall) Value {
			propertyName := toString(call.Argument(0))
			thisObject := call.thisObject()
			return toValue(thisObject.hasOwnProperty(propertyName))
		},
		"isPrototypeOf", func(call FunctionCall) Value {
			value := call.Argument(0)
			if !value.IsObject() {
				return FalseValue()
			}
			prototype := call.toObject(value).prototype
			thisObject := call.thisObject()
			for prototype != nil {
				if thisObject == prototype {
					return TrueValue()
				}
				prototype = prototype.prototype
			}
			return FalseValue()
		},
		"propertyIsEnumerable", func(call FunctionCall) Value {
			propertyName := toString(call.Argument(0))
			thisObject := call.thisObject()
			property := thisObject.getOwnProperty(propertyName)
			if property != nil && property.enumerable() {
				return TrueValue()
			}
			return FalseValue()
		},
	)
	self.Global.Object.write(
		"getOwnPropertyDescriptor", 2, builtinObject_getOwnPropertyDescriptor,
		"defineProperty", 3, builtinObject_defineProperty,
		"defineProperties", 2, builtinObject_defineProperties,
		"create", 2, builtinObject_create,
	)

	self.Global.Function = self.newGlobalFunction(
		1,
		"Function", builtinFunction,
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
		"Array", builtinArray,
		builtinNewArray,
		self.Global.ArrayPrototype,
		"toString", func(call FunctionCall) Value {
			thisObject := call.thisObject()
			join := thisObject.get("join")
			if join.isCallable() {
				join := join._object()
				if join._Function.Call.name() == "nativeArray_join" {
					if stash, isArray := thisObject.stash.(*_arrayStash); isArray {
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
		"String", builtinString,
		builtinNewString,
		self.Global.StringPrototype,
		"toString", func(call FunctionCall) Value {
			return *call.thisClassObject("String").primitive
		},
		"valueOf", func(call FunctionCall) Value {
			return *call.thisClassObject("String").primitive
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
		"substr", 2, builtinString_substr,
	)
	// TODO Maybe streamline this redundancy?
	self.Global.String.write(
		"fromCharCode", 1, builtinString_fromCharCode,
	)

	self.Global.Boolean = self.newGlobalFunction(
		1,
		"Boolean", builtinBoolean,
		builtinNewBoolean,
		self.Global.BooleanPrototype,
		"toString", func(call FunctionCall) Value {
			value := call.This
			if !value.IsBoolean() {
				// Will throw a TypeError if ThisObject is not a Boolean
				value = call.thisClassObject("Boolean").primitiveValue()
			}
			return toValue(toString(value))
		},
		"valueOf", func(call FunctionCall) Value {
			value := call.This
			if !value.IsBoolean() {
				value = call.thisClassObject("Boolean").primitiveValue()
			}
			return value
		},
	)

	self.Global.Number = self.newGlobalFunction(
		1,
		"Number", builtinNumber,
		builtinNewNumber,
		self.Global.NumberPrototype,
		"toString", func(call FunctionCall) Value {
			// Will throw a TypeError if ThisObject is not a Number
			value := call.thisClassObject("Number").primitiveValue()
			radix := 10
			if len(call.ArgumentList) > 0 {
				integer := _toInteger(call.Argument(0))
				if integer < 2 || integer > 36 {
					panic(newRangeError("RangeError: toString() radix must be between 2 and 36"))
				}
				radix = int(integer)
			}
			if radix == 10 {
				return toValue(toString(value))
			}
			return toValue(numberToStringRadix(value, radix))
		},
		"valueOf", func(call FunctionCall) Value {
			return *call.thisClassObject("Number").primitive
		},
		// TODO toFixed
		// TODO toExponential
		// TODO toPrecision
	)

	self.Global.Number.write(
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
		"exp", 1, builtinMath_exp,
		"floor", 1, builtinMath_floor,
		"random", 0, builtinMath_random,
		"pow", 2, builtinMath_pow,
		_propertyMode(0),
		"E", toValue(math.E),
		"LN10", toValue(math.Ln10),
		"LN2", toValue(math.Ln2),
		"LOG2E", toValue(math.Log2E),
		"LOG10E", toValue(math.Log10E),
		"PI", toValue(math.Pi),
		"SQRT1_2", toValue(sqrt1_2),
		"SQRT2", toValue(math.Sqrt2),
	)

	self.Global.Date = self.newGlobalFunction(
		7,
		"Date", builtinDate,
		builtinNewDate,
		self.Global.DatePrototype,
		"toString", 0, builtinDate_toString,
		"toUTCString", 0, builtinDate_toUTCString,
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
		"RegExp", builtinRegExp,
		builtinNewRegExp,
		self.Global.RegExpPrototype,
		"toString", 0, builtinRegExp_toString,
		"exec", 1, builtinRegExp_exec,
		"test", 1, builtinRegExp_test,
	)

	self.Global.Error = self.newGlobalFunction(
		1,
		"Error", builtinError,
		builtinNewError,
		self.Global.ErrorPrototype,
		"name", toValue("Error"),
		"toString", 0, builtinError_toString,
	)

	self.GlobalObject.write(
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
	self.primitive = &value
	return self
}

func (runtime *_runtime) newObject() *_object {
	self := runtime.newClassObject("Object")
	self.prototype = runtime.Global.ObjectPrototype
	return self
}

func (runtime *_runtime) newArray(valueArray []Value) *_object {
	self := runtime.newArrayObject(valueArray)
	self.prototype = runtime.Global.ArrayPrototype
	return self
}

func (runtime *_runtime) newString(value Value) *_object {
	self := runtime.newStringObject(value)
	self.prototype = runtime.Global.StringPrototype
	return self
}

func (runtime *_runtime) newBoolean(value Value) *_object {
	self := runtime.newBooleanObject(value)
	self.prototype = runtime.Global.BooleanPrototype
	return self
}

func (runtime *_runtime) newNumber(value Value) *_object {
	self := runtime.newNumberObject(value)
	self.prototype = runtime.Global.NumberPrototype
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
	self.prototype = runtime.Global.RegExpPrototype
	return self
}

// TODO Should (probably) be one argument, right? This is redundant
func (runtime *_runtime) newDate(epoch float64) *_object {
	self := runtime.newDateObject(epoch)
	self.prototype = runtime.Global.DatePrototype
	return self
}

func (runtime *_runtime) newError(name string, message Value) *_object {
	var self *_object
	_newError := runtime._newError[name]
	if _newError != nil {
		self = _newError(message)
	} else {
		self = runtime.newErrorObject(message)
		self.prototype = runtime.Global.ErrorPrototype
		if name != "" {
			self.set("name", toValue(name), false)
		}
	}
	return self
}

func (runtime *_runtime) newNativeFunction(_nativeFunction _nativeFunction, length int, name string) *_object {
	self := runtime.newNativeFunctionObject(_nativeFunction, length, name)
	self.prototype = runtime.Global.FunctionPrototype
	prototype := runtime.newObject()
	self.stash.set("prototype", toValue(prototype), _propertyMode(0100))
	prototype.stash.set("constructor", toValue(self), _propertyMode(0101))
	return self
}

func (runtime *_runtime) newNodeFunction(node *_functionNode, scopeEnvironment _environment) *_object {
	// TODO Implement 13.2 fully
	self := runtime.newNodeFunctionObject(node, scopeEnvironment)
	self.prototype = runtime.Global.FunctionPrototype
	prototype := runtime.newObject()
	self.stash.set("prototype", toValue(prototype), _propertyMode(0100))
	prototype.stash.set("constructor", toValue(self), _propertyMode(0101))
	return self
}

func (runtime *_runtime) newErrorPrototype(name string) *_object {
	prototype := runtime.newClassObject("Error")
	prototype.set("name", toValue(name), false)
	prototype.prototype = runtime.Global.ErrorPrototype
	return prototype
}

func (runtime *_runtime) defineError(name string) func(Value) *_object {
	prototype := runtime.newErrorPrototype(name) // "TypeError"

	errorFunction := func(message Value) *_object {
		error := runtime.newErrorObject(message)
		error.prototype = prototype
		return error
	}

	runtime.GlobalObject.set(name, toValue(runtime.newGlobalFunction(
		1,
		// e.g. TypeError( ... )
		name,
		func(call FunctionCall) Value { // TypeError( ... )
			return toValue(errorFunction(call.Argument(0)))
		},
		// e.g. new TypeError( ... )
		func(self *_object, _ Value, argumentList []Value) Value {
			return toValue(errorFunction(valueOfArrayIndex(argumentList, 0)))
		},
		prototype,
	)), false)

	return errorFunction
}
