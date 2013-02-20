package otto

import (
	"fmt"
)

// RegExp

func builtinRegExp(call FunctionCall) Value {
	return toValue(call.runtime.newRegExp(call.Argument(0), call.Argument(1)))
}

func builtinNewRegExp(self *_object, _ Value, argumentList []Value) Value {
	return toValue(self.runtime.newRegExp(valueOfArrayIndex(argumentList, 0), valueOfArrayIndex(argumentList, 1)))
}

func builtinRegExp_toString(call FunctionCall) Value {
	thisObject := call.thisObject()
	source := toString(thisObject.get("source"))
	flags := []byte{}
	if toBoolean(thisObject.get("global")) {
		flags = append(flags, 'g')
	}
	if toBoolean(thisObject.get("ignoreCase")) {
		flags = append(flags, 'i')
	}
	if toBoolean(thisObject.get("multiline")) {
		flags = append(flags, 'm')
	}
	return toValue(fmt.Sprintf("/%s/%s", source, flags))
}

func builtinRegExp_exec(call FunctionCall) Value {
	thisObject := call.thisObject()
	target := toString(call.Argument(0))
	match, result := execRegExp(thisObject, target)
	if !match {
		return NullValue()
	}
	return toValue(execResultToArray(call.runtime, target, result))
}

func builtinRegExp_test(call FunctionCall) Value {
	thisObject := call.thisObject()
	target := toString(call.Argument(0))
	match, _ := execRegExp(thisObject, target)
	return toValue(match)
}
