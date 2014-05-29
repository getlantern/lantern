package otto

import (
	"fmt"
	"regexp"
	"strings"
	"unicode"

	"github.com/robertkrimen/otto/parser"
)

// Function

func builtinFunction(call FunctionCall) Value {
	return toValue_object(builtinNewFunctionNative(call.runtime, call.ArgumentList))
}

func builtinNewFunction(self *_object, argumentList []Value) Value {
	return toValue_object(builtinNewFunctionNative(self.runtime, argumentList))
}

func argumentList2parameterList(argumentList []Value) []string {
	parameterList := make([]string, 0, len(argumentList))
	for _, value := range argumentList {
		tmp := strings.FieldsFunc(toString(value), func(chr rune) bool {
			return chr == ',' || unicode.IsSpace(chr)
		})
		parameterList = append(parameterList, tmp...)
	}
	return parameterList
}

var matchIdentifier = regexp.MustCompile(`^[$_\p{L}][$_\p{L}\d}]*$`)

func builtinNewFunctionNative(runtime *_runtime, argumentList []Value) *_object {
	var parameterList, body string
	count := len(argumentList)
	if count > 0 {
		tmp := make([]string, 0, count-1)
		for _, value := range argumentList[0 : count-1] {
			tmp = append(tmp, toString(value))
		}
		parameterList = strings.Join(tmp, ",")
		body = toString(argumentList[count-1])
	}

	function, err := parser.ParseFunction(parameterList, body)
	runtime.parseThrow(err) // Will panic/throw appropriately
	cmpl_function := parseExpression(function)

	return runtime.newNodeFunction(cmpl_function.(*_nodeFunctionLiteral), runtime.globalStash)
}

func builtinFunction_toString(call FunctionCall) Value {
	object := call.thisClassObject("Function") // Should throw a TypeError unless Function
	switch fn := object.value.(type) {
	case _nativeFunctionObject:
		return toValue_string(fmt.Sprintf("function %s() { [native code] }", fn.name))
	case _nodeFunctionObject:
		return toValue_string(fn.node.source)
	case _bindFunctionObject:
		return toValue_string("function () { [native code] }")
	}

	panic(newTypeError("Function.toString()"))
}

func builtinFunction_apply(call FunctionCall) Value {
	if !call.This.isCallable() {
		panic(newTypeError())
	}
	this := call.Argument(0)
	if this.IsUndefined() {
		// FIXME Not ECMA5
		this = toValue_object(call.runtime.globalObject)
	}
	argumentList := call.Argument(1)
	switch argumentList.kind {
	case valueUndefined, valueNull:
		return call.thisObject().call(this, nil, false)
	case valueObject:
	default:
		panic(newTypeError())
	}

	arrayObject := argumentList._object()
	thisObject := call.thisObject()
	length := int64(toUint32(arrayObject.get("length")))
	valueArray := make([]Value, length)
	for index := int64(0); index < length; index++ {
		valueArray[index] = arrayObject.get(arrayIndexToString(index))
	}
	return thisObject.call(this, valueArray, false)
}

func builtinFunction_call(call FunctionCall) Value {
	if !call.This.isCallable() {
		panic(newTypeError())
	}
	thisObject := call.thisObject()
	this := call.Argument(0)
	if this.IsUndefined() {
		// FIXME Not ECMA5
		this = toValue_object(call.runtime.globalObject)
	}
	if len(call.ArgumentList) >= 1 {
		return thisObject.call(this, call.ArgumentList[1:], false)
	}
	return thisObject.call(this, nil, false)
}

func builtinFunction_bind(call FunctionCall) Value {
	target := call.This
	if !target.isCallable() {
		panic(newTypeError())
	}
	targetObject := target._object()

	this := call.Argument(0)
	argumentList := call.slice(1)
	if this.IsUndefined() {
		// FIXME Do this elsewhere?
		this = toValue_object(call.runtime.globalObject)
	}

	return toValue_object(call.runtime.newBoundFunction(targetObject, this, argumentList))
}
