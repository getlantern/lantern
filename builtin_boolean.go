package otto

// Boolean

func builtinBoolean(call FunctionCall) Value {
	return toValue(toBoolean(call.Argument(0)))
}

func builtinNewBoolean(self *_object, _ Value, argumentList []Value) Value {
	return toValue(self.runtime.newBoolean(valueOfArrayIndex(argumentList, 0)))
}
