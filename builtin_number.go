package otto

// Number

func numberValueFromNumberArgumentList(argumentList []Value) Value {
	if len(argumentList) > 0 {
		return toValue(toNumber(argumentList[0]))
	}
	return toValue(0)
}

func builtinNumber(call FunctionCall) Value {
	return numberValueFromNumberArgumentList(call.ArgumentList)
}

func builtinNewNumber(self *_object, _ Value, argumentList []Value) Value {
	return toValue(self.runtime.newNumber(numberValueFromNumberArgumentList(argumentList)))
}
