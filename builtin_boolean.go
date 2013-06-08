package otto

// Boolean

func builtinBoolean(call FunctionCall) Value {
	return toValue(toBoolean(call.Argument(0)))
}

func builtinNewBoolean(self *_object, _ Value, argumentList []Value) Value {
	return toValue(self.runtime.newBoolean(valueOfArrayIndex(argumentList, 0)))
}

func builtinBoolean_toString(call FunctionCall) Value {
	value := call.This
	if !value.IsBoolean() {
		// Will throw a TypeError if ThisObject is not a Boolean
		value = call.thisClassObject("Boolean").primitiveValue()
	}
	return toValue(toString(value))
}

func builtinBoolean_valueOf(call FunctionCall) Value {
	value := call.This
	if !value.IsBoolean() {
		value = call.thisClassObject("Boolean").primitiveValue()
	}
	return value
}
