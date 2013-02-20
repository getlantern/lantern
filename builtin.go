package otto

import (
	"fmt"
	"math"
	"net/url"
	"regexp"
	"strconv"
	"strings"
)

// Global
func builtinGlobal_eval(call FunctionCall) Value {
	source := call.Argument(0)
	if !source.IsString() {
		return source
	}
	program, err := parse(toString(source))
	if err != nil {
		//panic(call.runtime.newError("SyntaxError", UndefinedValue()))
		panic(&_syntaxError{Message: fmt.Sprintf("%v", err)})
	}
	runtime := call.runtime
	runtime.EnterEvalExecutionContext(call)
	defer runtime.LeaveExecutionContext()
	returnValue := runtime.evaluate(program)
	if returnValue.isEmpty() {
		return UndefinedValue()
	}
	return returnValue
}

func builtinGlobal_isNaN(call FunctionCall) Value {
	value := toFloat(call.Argument(0))
	return toValue(math.IsNaN(value))
}

func builtinGlobal_isFinite(call FunctionCall) Value {
	value := toFloat(call.Argument(0))
	return toValue(!math.IsNaN(value) && !math.IsInf(value, 0))
}

func builtinGlobal_parseInt(call FunctionCall) Value {
	// Caveat emptor: This implementation does NOT match the specification
	string_ := strings.TrimSpace(toString(call.Argument(0)))
	radix := call.Argument(1)
	radixValue := 0
	if radix.IsDefined() {
		radixValue = int(toInt32(radix))
	}
	value, err := strconv.ParseInt(string_, radixValue, 64)
	if err != nil {
		return NaNValue()
	}
	return toValue(value)
}

func builtinGlobal_parseFloat(call FunctionCall) Value {
	// Caveat emptor: This implementation does NOT match the specification
	string_ := strings.TrimSpace(toString(call.Argument(0)))
	value, err := strconv.ParseFloat(string_, 64)
	if err != nil {
		return NaNValue()
	}
	return toValue(value)
}

func _builtinGlobal_encodeURI(call FunctionCall, characterRegexp *regexp.Regexp) Value {
	value := []byte(toString(call.Argument(0)))
	value = characterRegexp.ReplaceAllFunc(value, func(target []byte) []byte {
		// Probably a better way of doing this
		if target[0] == ' ' {
			return []byte("%20")
		}
		return []byte(url.QueryEscape(string(target)))
	})
	return toValue(string(value))
}

var encodeURI_Regexp = regexp.MustCompile(`([^~!@#$&*()=:/,;?+'])`)

func builtinGlobal_encodeURI(call FunctionCall) Value {
	return _builtinGlobal_encodeURI(call, encodeURI_Regexp)
}

var encodeURIComponent_Regexp = regexp.MustCompile(`([^~!*()'])`)

func builtinGlobal_encodeURIComponent(call FunctionCall) Value {
	return _builtinGlobal_encodeURI(call, encodeURIComponent_Regexp)
}

func builtinGlobal_decodeURI_decodeURIComponent(call FunctionCall) Value {
	value, err := url.QueryUnescape(toString(call.Argument(0)))
	if err != nil {
		panic(newURIError("URI malformed"))
	}
	return toValue(value)
}

// Error

func builtinError(call FunctionCall) Value {
	return toValue(call.runtime.newError("", call.Argument(0)))
}

func builtinNewError(self *_object, _ Value, argumentList []Value) Value {
	return toValue(self.runtime.newError("", valueOfArrayIndex(argumentList, 0)))
}

func builtinError_toString(call FunctionCall) Value {
	thisObject := call.thisObject()
	if thisObject == nil {
		panic(newTypeError())
	}

	name := "Error"
	nameValue := thisObject.get("name")
	if nameValue.IsDefined() {
		name = toString(nameValue)
	}

	message := ""
	messageValue := thisObject.get("message")
	if messageValue.IsDefined() {
		message = toString(messageValue)
	}

	if len(name) == 0 {
		return toValue(message)
	}

	if len(message) == 0 {
		return toValue(name)
	}

	return toValue(fmt.Sprintf("%s: %s", name, message))
}
