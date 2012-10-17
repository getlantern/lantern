package otto

import (
	"strconv"
	//"fmt"
)

type _runtime struct {
    Stack [](*_executionContext)

	GlobalObject *_object
    GlobalEnvironment *_objectEnvironment

	Global struct {
		Object *_object // Object( ... ), new Object( ... ) - 1 (length)
		Function *_object // Function( ... ), new Function( ... ) - 1
		Array *_object // Array( ... ), new Array( ... ) - 1
		String *_object // String( ... ), new String( ... ) - 1
		Boolean *_object // Boolean( ... ), new Boolean( ... ) - 1
		Number *_object // Number( ... ), new Number( ... ) - 1
		Math *_object
		Date *_object // Date( ... ), new Date( ... ) - 7
		RegExp *_object // RegExp( ... ), new RegExp( ... ) - 2
		Error *_object // Error( ... ), new Error( ... ) - 1
		// JSON

		ObjectPrototype *_object // Object.prototype
		FunctionPrototype *_object // Function.prototype
		ArrayPrototype *_object // Array.prototype
		StringPrototype *_object // String.prototype
		BooleanPrototype *_object // Boolean.prototype
		NumberPrototype *_object // Number.prototype
		DatePrototype *_object // Date.prototype
		RegExpPrototype *_object // RegExp.prototype
		ErrorPrototype *_object // Error.prototype
	}

	_newError map[string] func(Value) *_object
}

func (self *_runtime) EnterGlobalExecutionContext() {
    self.EnterExecutionContext(newExecutionContext(self.GlobalEnvironment, self.GlobalEnvironment, self.GlobalObject))
}

func (self *_runtime) EnterExecutionContext(scope *_executionContext) {
    self.Stack = append(self.Stack, scope)
}

func (self *_runtime) LeaveExecutionContext() {
    self.Stack = self.Stack[:len(self.Stack)-1]
}

func (self *_runtime) _executionContext(depth int) *_executionContext {
	if depth == 0 {
		return self.Stack[len(self.Stack)-1]
	}
	if len(self.Stack)-1+depth >= 0 {
		return self.Stack[len(self.Stack)-1+depth]
	}
	return nil
}

func (self *_runtime) EnterFunctionExecutionContext(function *_object, this Value) *_functionEnvironment {
	scopeEnvironment := function.Function.Call.ScopeEnvironment()
	if scopeEnvironment == nil {
		scopeEnvironment = self.GlobalEnvironment
	}
	environment := self.newFunctionEnvironment(scopeEnvironment)
	var thisObject *_object
	switch this._valueType {
	case valueUndefined, valueNull:
		thisObject = self.GlobalObject
	default:
		thisObject = self.toObject(this)
	}
    self.EnterExecutionContext(newExecutionContext(environment, environment, thisObject))
	return environment
}

func (self *_runtime) EnterEvalExecutionContext(call FunctionCall) {
	// Skip the current function lexical/variable environment, which is of the function execution context call
	// to eval (the global execution context). Instead, execute in the context of where the eval was called,
	// which is essentially dynamic scoping
	_executionContext := self._executionContext(-1)
	self.EnterExecutionContext(newExecutionContext(_executionContext.LexicalEnvironment, _executionContext.VariableEnvironment, nil))
}

func (self *_runtime) Return(value Value) {
	panic(newReturnResult(value))
}

func (self *_runtime) Continue(target string) {
	panic(newContinueResult(target))
}

func (self *_runtime) Break(target string) {
	panic(newBreakResult(target))
}

func (self *_runtime) Throw(value Value) {
	panic(newThrowResult(value))
}

func (self *_runtime) GetValue(value Value) Value {
	if value.isReference() {
		return value.reference().GetValue()
	}
	return value
}

func (self *_runtime) PutValue(reference _reference, value Value) {
	if !reference.PutValue(value) {
		// Why? -- If reference.Base == nil
		strict := false
		self.GlobalObject.WriteValue(reference.Name(), value, strict)
	}
}

func (self *_runtime) _callNode(environment *_functionEnvironment, node *_functionNode, this Value, argumentList []Value) Value {

	self.declare("function", node.FunctionList)

	if node.ArgumentsIsParameter {
		for i, name := range node.ParameterList {
			value := UndefinedValue()
			if i < len(argumentList) {
				value = argumentList[i]
			}
			self.localSet(name, value)
		}
	} else {
		// FIXME Why does this work before but not after?
		for index := len(argumentList); index < len(node.ParameterList); index++ {
			name := node.ParameterList[index]
			self.localSet(name, UndefinedValue())
		}
		arguments := self.newArgumentsObject(argumentList)
		environment.arguments = arguments
		self.localSet("arguments", toValue(arguments))
		indexOfArgumentName := map[string]string{}
		for index, _ := range argumentList {
			if index >= len(node.ParameterList) {
				break
			}
			name := node.ParameterList[index]
			indexOfArgumentName[name] = strconv.FormatInt(int64(index), 10)
		}
		environment.indexOfArgumentName = indexOfArgumentName
	}

	self.declare("variable", node.VariableList)

	self.evaluateBody(node.Body)

	return UndefinedValue()
}

func (self *_runtime) Call(function *_object, this Value, argumentList []Value) (returnValue Value) {
	_functionEnvironment := self.EnterFunctionExecutionContext(function, this)
	defer func(){
		// TODO Catch any errant break/continue, etc. here?
		//		They should never get here, but we want to be
		//		very vocal if they do.
		self.LeaveExecutionContext();
		if caught := recover(); caught != nil {
			if result, ok := caught.(_result); ok {
					if result.Kind == resultReturn {
						returnValue = result.Value
						return
					}
			}
			panic(caught)
		}
	}()

    returnValue = function.Function.Call.Dispatch(_functionEnvironment, self, this, argumentList)
	return
}

func (self *_runtime) tryEvaluate(inner func() Value) (tryValue Value, throw bool, throwValue Value) {
	defer func(){
		if caught := recover(); caught != nil {
			switch caught := caught.(type) {
			case _result:
				if caught.Kind == resultThrow {
					throw = true
					throwValue = caught.Value
					return
				}
			case _error:
				throw = true
				throwValue = toValue(self.newError(caught.Name, caught.MessageValue()))
				return
			case *_syntaxError:
				throw = true
				throwValue = toValue(self.newError("SyntaxError", toValue(caught.String())))
				return
			}
			panic(caught)
		}
	}()

	tryValue = inner()
	return
}

func (self *_runtime) breakEvaluate(_labelSet map[string]bool, inner func() Value) Value {
	defer func(){
		if caught := recover(); caught != nil {
			if result, ok := caught.(_result); ok {
					if result.Kind == resultBreak && _labelSet[result.Target] == true {
						return
					}
			}
			panic(caught)
		}
	}()

	return inner()
}

func (self *_runtime) continueEvaluate(node _node, _labelSet map[string]bool) (returnResult Value, skip bool) {
	defer func(){
		if caught := recover(); caught != nil {
			if result, ok := caught.(_result); ok {
					if result.Kind == resultContinue && _labelSet[result.Target] == true {
						returnResult = emptyValue()
						skip = true
						return
					}
			}
			panic(caught)
		}
	}()
	return self.evaluate(node), false
}

func (self *_runtime) declare(kind string, declarationList []_declaration) {
	for _, _declaration := range declarationList {
		self.localSet(_declaration.Name, UndefinedValue())
		if kind == "function" {
			value := self.evaluate(_declaration.Definition)
			self.localSet(_declaration.Name, value)
		}
	}
}

// _executionContext Proxy

func (self *_runtime) localGet(name string) Value {
    return self._executionContext(0).GetValue(name)
}

func (self *_runtime) localSet(name string, value Value) {
    self._executionContext(0).SetValue(name, value, false)
}

func (self *_runtime) VariableEnvironment() _environment {
    return self._executionContext(0).VariableEnvironment
}

func (self *_runtime) LexicalEnvironment() _environment {
    return self._executionContext(0).LexicalEnvironment
}

// toObject

func (self *_runtime) toObject(value Value) *_object {
	switch value._valueType {
	case valueEmpty, valueUndefined, valueNull:
		panic(newTypeError())
	case valueBoolean:
		return self.newBoolean(value)
	case valueString:
		return self.newString(value)
	case valueNumber:
		return self.newNumber(value)
	case valueObject:
		return value._object()
	}
	panic(newTypeError())
}

func checkObjectCoercible(value Value) {
	isObject, mustCoerce := testObjectCoercible(value)
	if !isObject && !mustCoerce {
		panic(newTypeError())
	}
}

// testObjectCoercible

func testObjectCoercible(value Value) (isObject bool, mustCoerce bool) {
	switch value._valueType {
	case valueReference, valueEmpty, valueNull, valueUndefined:
		return false, false
	case valueNumber, valueString, valueBoolean:
		isObject = false
		mustCoerce = true
	case valueObject:
		isObject = true
		mustCoerce = false
	}
	return
}

func (self *_runtime) toValue(value interface{}) Value {
	switch value := value.(type) {
	case func(FunctionCall) Value:
		return toValue(self.newNativeFunction(value, 0))
	case _nativeFunction:
		return toValue(self.newNativeFunction(value, 0))
	}
	return toValue(value)
}
