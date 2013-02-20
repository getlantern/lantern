package otto

// Function

func builtinFunction(call FunctionCall) Value {
	return toValue(builtinNewFunctionNative(call.runtime, call.ArgumentList))
}

func builtinNewFunction(self *_object, _ Value, argumentList []Value) Value {
	return toValue(builtinNewFunctionNative(self.runtime, argumentList))
}

func builtinNewFunctionNative(runtime *_runtime, argumentList []Value) *_object {
	parameterList := []string{}
	bodySource := ""
	argumentCount := len(argumentList)
	if argumentCount > 0 {
		bodySource = toString(argumentList[argumentCount-1])
		argumentList = argumentList[0 : argumentCount-1]
		for _, value := range argumentList {
			parameterList = append(parameterList, toString(value))
		}
	}

	parser := newParser()
	parser.lexer.Source = bodySource
	_programNode := parser.ParseAsFunction()
	return runtime.newNodeFunction(_programNode.toFunction(parameterList), runtime.GlobalEnvironment)
}

func builtinFunction_apply(call FunctionCall) Value {
	if !call.This.isCallable() {
		panic(newTypeError())
	}
	this := call.Argument(0)
	if this.IsUndefined() {
		// FIXME Not ECMA5
		this = toValue(call.runtime.GlobalObject)
	}
	argumentList := call.Argument(1)
	switch argumentList._valueType {
	case valueUndefined, valueNull:
		return call.thisObject().Call(this, []Value{})
	case valueObject:
	default:
		panic(newTypeError())
	}

	arrayObject := argumentList._object()
	thisObject := call.thisObject()
	length := uint(toUint32(arrayObject.get("length")))
	valueArray := make([]Value, length)
	for index := uint(0); index < length; index++ {
		valueArray[index] = arrayObject.get(arrayIndexToString(index))
	}
	return thisObject.Call(this, valueArray)
}

func builtinFunction_call(call FunctionCall) Value {
	if !call.This.isCallable() {
		panic(newTypeError())
	}
	thisObject := call.thisObject()
	this := call.Argument(0)
	if this.IsUndefined() {
		// FIXME Not ECMA5
		this = toValue(call.runtime.GlobalObject)
	}
	if len(call.ArgumentList) >= 1 {
		return thisObject.Call(this, call.ArgumentList[1:])
	}
	return thisObject.Call(this, []Value{})
}
