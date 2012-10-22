package otto

import (
	"math"
)

type _valueType int

const (
	valueEmpty _valueType = iota
	valueNull
	valueUndefined
	valueNumber
	valueString
	valueBoolean
	valueObject
	valueReference
)

// Value is the representation of a JavaScript value.
type Value struct {
	_valueType
	value interface{}
}

func ToValue(value interface{}) (Value, error) {
	result := UndefinedValue()
	err := catchPanic(func(){
		result = toValue(value)
	})
	return result, err
}

// Empty

func emptyValue() Value {
	return Value{_valueType: valueEmpty}
}

func (value Value) isEmpty() bool {
	return value._valueType == valueEmpty
}

// Undefined

// UndefinedValue will return a Value representing undefined.
func UndefinedValue() Value {
	return Value{_valueType: valueUndefined}
}

// IsDefined will return false if the value is undefined, and true otherwise.
func (value Value) IsDefined() bool {
    return value._valueType != valueUndefined
}

// IsUndefined will return true if the value is undefined, and false otherwise.
func (value Value) IsUndefined() bool {
    return value._valueType == valueUndefined
}

// Any nil will do -- we just make a new throwaway type here

// NullValue will return a Value representing null.
func NullValue() Value {
	return Value{_valueType: valueNull}
}

// IsNull will return true if the value is null, and false otherwise.
func (value Value) IsNull() bool {
	return value._valueType == valueNull
}

// ---

func (value Value) isCallable() bool {
	switch value := value.value.(type) {
    case *_object:
		return value._Function != nil
    }
    return false
}

func (value Value) isReference() bool {
    return value._valueType == valueReference
}

// Call the value as a function with the given this value and argument list and
// return the result of invocation. It is essentially equivalent to:
//
//		value.apply(thisValue, argumentList)
//
// An undefined value and an error will result if:
//
//		1. There is an error during conversion of the argument list
//		2. The value is not actually a function
//		3. An (uncaught) exception is thrown
//
func (value Value) Call(this Value, argumentList... interface{}) (Value, error) {
	result := UndefinedValue()
	err := catchPanic(func(){
		result = value.call(this, argumentList...)
	})
	return result, err
}

func (value Value) call(this Value, argumentList... interface{}) Value {
    switch value := value.value.(type) {
    case *_object:
        return value.Call(this, argumentList...)
    }
	panic(newTypeError())
}

// IsPrimitive will return true if value is a primitive (any kind of primitive).
func (value Value) IsPrimitive() bool {
	return ! value.IsObject()
}

// IsBoolean will return true if value is a boolean (primitive).
func (value Value) IsBoolean() bool {
	return value._valueType == valueBoolean
}

// IsNumber will return true if value is a number (primitive).
func (value Value) IsNumber() bool {
	return value._valueType == valueNumber
}

// IsNaN will return true if value is NaN (or would convert to NaN).
func (value Value) IsNaN() bool {
	switch value := value.value.(type) {
	case float64:
		return math.IsNaN(value)
	case float32:
		return math.IsNaN(float64(value))
	case int, int8, int32, int64:
		return false
	case uint, uint8, uint32, uint64:
		return false
	}

	return math.IsNaN(toFloat(value))
}

// IsString will return true if value is a string (primitive).
func (value Value) IsString() bool {
	return value._valueType == valueString
}

// IsObject will return true if value is an object.
func (value Value) IsObject() bool {
	return value._valueType == valueObject
}

// IsFunction will return true if value is a function.
func (value Value) IsFunction() bool {
	if value._valueType != valueObject {
		return false
	}
	return value.value.(*_object).class == "Function"
}

// Class will return the class string of the value or the empty string if value is not an object.
//
// The return value will (generally) be one of:
//
//		Object
//		Function
//		Array
//		String
//		Number
//		Boolean
//		Date
//		RegExp
//
func (value Value) Class() string {
	if value._valueType != valueObject {
		return ""
	}
	return value.value.(*_object).class
}

func (value Value) isArray() bool {
	if value._valueType != valueObject {
		return false
	}
	return value.value.(*_object).class == "Array"
}

func (value Value) isStringObject() bool {
	if value._valueType != valueObject {
		return false
	}
	return value.value.(*_object).class == "String"
}

func (value Value) isBooleanObject() bool {
	if value._valueType != valueObject {
		return false
	}
	return value.value.(*_object).class == "Boolean"
}

func (value Value) isNumberObject() bool {
	if value._valueType != valueObject {
		return false
	}
	return value.value.(*_object).class == "Number"
}

func (value Value) isDate() bool {
	if value._valueType != valueObject {
		return false
	}
	return value.value.(*_object).class == "Date"
}

func (value Value) isRegExp() bool {
	if value._valueType != valueObject {
		return false
	}
	return value.value.(*_object).class == "RegExp"
}

func (value Value) isError() bool {
	if value._valueType != valueObject {
		return false
	}
	return value.value.(*_object).class == "Error"
}

// ---

func toValue(value interface{}) Value {
	switch value := value.(type) {
    case Value:
        return value
	case bool:
		return Value{valueBoolean, value}
	case int:
		return Value{valueNumber, value}
	case int8:
		return Value{valueNumber, value}
	case int16:
		return Value{valueNumber, value}
	case int32:
		return Value{valueNumber, value}
	case int64:
		return Value{valueNumber, value}
	case uint:
		return Value{valueNumber, value}
	case uint8:
		return Value{valueNumber, value}
	case uint16:
		return Value{valueNumber, value}
	case uint32:
		return Value{valueNumber, value}
	case uint64:
		return Value{valueNumber, value}
	case float32:
		return Value{valueNumber, float64(value)}
	case float64:
		return Value{valueNumber, value}
	case string:
		return Value{valueString, value}
	// A rune is actually an int32, which is handled above
	case *_object:
		return Value{valueObject, value}
	case *Object:
		return Value{valueObject, value.object}
	case Object:
		return Value{valueObject, value.object}
	case _reference: // reference is an interface (already a pointer)
		return Value{valueReference, value}
    }
	panic(newTypeError("Unable to convert value: %v (%T)", value, value))
}

// String will return the value as a string.
//
// This method will make return the empty string if there is an error.
func (value Value) String() string {
	result := ""
	catchPanic(func(){
		result = value.toString()
	})
	return result
}

func (value Value) toBoolean() bool {
	return toBoolean(value)
}

// ToBoolean will convert the value to a boolean (bool).
//
//		ToValue(0).ToBoolean() => false
//		ToValue("").ToBoolean() => false
//		ToValue(true).ToBoolean() => true
//		ToValue(1).ToBoolean() => true
//		ToValue("Nothing happens").ToBoolean() => true
//
// If there is an error during the conversion process (like an uncaught exception), then the result will be false and an error.
func (value Value) ToBoolean() (bool, error) {
	result := false
	err := catchPanic(func(){
		result = toBoolean(value)
	})
	return result, err
}

func (value Value) toNumber() Value {
	return toNumber(value)
}

func (value Value) toFloat() float64 {
	return toFloat(value)
}

// ToFloat will convert the value to a number (float64).
//
//		ToValue(0).ToFloat() => 0.
//		ToValue(1.1).ToFloat() => 1.1
//		ToValue("11").ToFloat() => 11.
//
// If there is an error during the conversion process (like an uncaught exception), then the result will be 0 and an error.
func (value Value) ToFloat() (float64, error) {
	result := float64(0)
	err := catchPanic(func(){
		result = toFloat(value)
	})
	return result, err
}

// ToInteger will convert the value to a number (int64).
//
//		ToValue(0).ToInteger() => 0
//		ToValue(1.1).ToInteger() => 1
//		ToValue("11").ToInteger() => 11
//
// If there is an error during the conversion process (like an uncaught exception), then the result will be 0 and an error.
func (value Value) ToInteger() (int64, error) {
	result := int64(0)
	err := catchPanic(func(){
		result = toInteger(value)
	})
	return result, err
}

func (value Value) toString() string {
	return toString(value)
}

// ToString will convert the value to a string (string).
//
//		ToValue(0).ToString() => "0"
//		ToValue(false).ToString() => "false"
//		ToValue(1.1).ToString() => "1.1"
//		ToValue("11").ToString() => "11"
//		ToValue('Nothing happens.').ToString() => "Nothing happens."
//
// If there is an error during the conversion process (like an uncaught exception), then the result will be the empty string ("") and an error.
func (value Value) ToString() (string, error) {
	result := ""
	err := catchPanic(func(){
		result = toString(value)
	})
	return result, err
}

func (value Value) _object() *_object {
	switch value := value.value.(type) {
	case *_object:
		return value
	}
    return nil
}

// Object will return the object of the value, or nil if value is not an object.
//
// This method will not do any implicit conversion. For example, calling this method on a string primitive value will not return a String object.
func (value Value) Object() *Object {
	switch object := value.value.(type) {
	case *_object:
		return _newObject(object, value)
	}
    return nil
}

func (value Value) reference() _reference {
	switch value := value.value.(type) {
	case _reference:
		return value
	}
    return nil
}

var __NaN__, __PositiveInfinity__, __NegativeInfinity__, __PositiveZero__, __NegativeZero__ float64
func init() {
	__NaN__ = math.NaN()
	__PositiveInfinity__ = math.Inf(+1)
	__NegativeInfinity__ = math.Inf(-1)
	__PositiveZero__ = 0
	__NegativeZero__ = math.Float64frombits(0|(1<<63))
}

func positiveInfinity() float64 {
	return __PositiveInfinity__
}

func negativeInfinity() float64 {
	return __NegativeInfinity__
}

func positiveZero() float64 {
	return __PositiveZero__
}

func negativeZero() float64 {
	return __NegativeZero__
}

// NaNValue will return a value representing NaN.
//
// It is equivalent to:
//
//		ToValue(math.NaN())
//
func NaNValue() Value {
	return Value{valueNumber, __NaN__}
}

func positiveInfinityValue() Value {
	return Value{valueNumber, __PositiveInfinity__}
}

func negativeInfinityValue() Value {
	return Value{valueNumber, __NegativeInfinity__}
}

func positiveZeroValue() Value {
	return Value{valueNumber, __PositiveZero__}
}

func negativeZeroValue() Value {
	return Value{valueNumber, __NegativeZero__}
}

// TrueValue will return a value represting true.
//
// It is equivalent to:
//
//		ToValue(true)
//
func TrueValue() Value {
	return Value{valueBoolean, true}
}

// FalseValue will return a value represting false.
//
// It is equivalent to:
//
//		ToValue(false)
//
func FalseValue() Value {
	return Value{valueBoolean, false}
}

func sameValue(x Value, y Value) bool {
	if x._valueType != y._valueType {
		return false
	}
	result := false
	switch x._valueType {
	case valueUndefined, valueNull:
		result = true
	case valueNumber:
		x := x.toFloat()
		y := y.toFloat()
		if math.IsNaN(x) && math.IsNaN(y) {
			result = true
		} else {
			result = x == y
			if result && x == 0 {
				// Since +0 != -0
				result = math.Signbit(x) == math.Signbit(y)
			}
		}
	case valueString:
		result = x.toString() == y.toString()
	case valueBoolean:
		result = x.toBoolean() == y.toBoolean()
	case valueObject:
		result = x._object() == y._object()
	default:
		panic(hereBeDragons())
	}

	return result
}
