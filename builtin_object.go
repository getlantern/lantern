package otto

import (
	"fmt"
)

// Object

func builtinObject(call FunctionCall) Value {
	value := call.Argument(0)
	switch value._valueType {
	case valueUndefined, valueNull:
		return toValue(call.runtime.newObject())
	}

	return toValue(call.runtime.toObject(value))
}

func builtinNewObject(self *_object, _ Value, argumentList []Value) Value {
	value := valueOfArrayIndex(argumentList, 0)
	switch value._valueType {
	case valueNull, valueUndefined:
	case valueNumber, valueString, valueBoolean:
		return toValue(self.runtime.toObject(value))
	case valueObject:
		return value
	default:
	}
	return toValue(self.runtime.newObject())
}

func builtinObject_toString(call FunctionCall) Value {
	result := ""
	if call.This.IsUndefined() {
		result = "[object Undefined]"
	} else if call.This.IsNull() {
		result = "[object Null]"
	} else {
		result = fmt.Sprintf("[object %s]", call.thisObject().class)
	}
	return toValue(result)
}

func builtinObject_toLocaleString(call FunctionCall) Value {
	toString := call.thisObject().get("toString")
	if !toString.isCallable() {
		panic(newTypeError())
	}
	return toString.call(call.This)
}

func builtinObject_getPrototypeOf(call FunctionCall) Value {
	objectValue := call.Argument(0)
	object := objectValue._object()
	if object == nil {
		panic(newTypeError())
	}

	if object.prototype == nil {
		return NullValue()
	}

	return toValue(object.prototype)
}

func builtinObject_getOwnPropertyDescriptor(call FunctionCall) Value {
	objectValue := call.Argument(0)
	object := objectValue._object()
	if object == nil {
		panic(newTypeError())
	}

	name := toString(call.Argument(1))
	descriptor := object.getOwnProperty(name)
	if descriptor == nil {
		return UndefinedValue()
	}
	return toValue(call.runtime.fromPropertyDescriptor(*descriptor))
}

func builtinObject_defineProperty(call FunctionCall) Value {
	objectValue := call.Argument(0)
	object := objectValue._object()
	if object == nil {
		panic(newTypeError())
	}
	name := toString(call.Argument(1))
	descriptor := toPropertyDescriptor(call.Argument(2))
	object.defineOwnProperty(name, descriptor, true)
	return objectValue
}

func builtinObject_defineProperties(call FunctionCall) Value {
	objectValue := call.Argument(0)
	object := objectValue._object()
	if object == nil {
		panic(newTypeError())
	}

	properties := call.runtime.toObject(call.Argument(1))
	properties.enumerate(func(name string) {
		descriptor := toPropertyDescriptor(properties.get(name))
		object.defineOwnProperty(name, descriptor, true)
	})

	return objectValue
}

func builtinObject_create(call FunctionCall) Value {
	prototypeValue := call.Argument(0)
	prototype := prototypeValue._object()
	if prototype == nil {
		panic(newTypeError())
	}

	object := call.runtime.newObject()

	propertiesValue := call.Argument(1)
	if propertiesValue.IsDefined() {
		properties := call.runtime.toObject(propertiesValue)
		properties.enumerate(func(name string) {
			descriptor := toPropertyDescriptor(properties.get(name))
			object.defineOwnProperty(name, descriptor, true)
		})
	}

	return toValue(object)
}
