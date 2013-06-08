package otto

import (
	"reflect"
	"strconv"
)

type _runtime struct {
	Stack [](*_executionContext)

	GlobalObject      *_object
	GlobalEnvironment *_objectEnvironment

	Global struct {
		Object         *_object // Object( ... ), new Object( ... ) - 1 (length)
		Function       *_object // Function( ... ), new Function( ... ) - 1
		Array          *_object // Array( ... ), new Array( ... ) - 1
		String         *_object // String( ... ), new String( ... ) - 1
		Boolean        *_object // Boolean( ... ), new Boolean( ... ) - 1
		Number         *_object // Number( ... ), new Number( ... ) - 1
		Math           *_object
		Date           *_object // Date( ... ), new Date( ... ) - 7
		RegExp         *_object // RegExp( ... ), new RegExp( ... ) - 2
		Error          *_object // Error( ... ), new Error( ... ) - 1
		EvalError      *_object
		TypeError      *_object
		RangeError     *_object
		ReferenceError *_object
		SyntaxError    *_object
		URIError       *_object
		// JSON

		ObjectPrototype         *_object // Object.prototype
		FunctionPrototype       *_object // Function.prototype
		ArrayPrototype          *_object // Array.prototype
		StringPrototype         *_object // String.prototype
		BooleanPrototype        *_object // Boolean.prototype
		NumberPrototype         *_object // Number.prototype
		DatePrototype           *_object // Date.prototype
		RegExpPrototype         *_object // RegExp.prototype
		ErrorPrototype          *_object // Error.prototype
		EvalErrorPrototype      *_object
		TypeErrorPrototype      *_object
		RangeErrorPrototype     *_object
		ReferenceErrorPrototype *_object
		SyntaxErrorPrototype    *_object
		URIErrorPrototype       *_object
	}

	eval *_object // The builtin eval, for determine indirect versus direct invocation

	Otto *Otto
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
	scopeEnvironment := function.functionValue().call.ScopeEnvironment()
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
	parent := self._executionContext(-1)
	new := newExecutionContext(parent.LexicalEnvironment, parent.VariableEnvironment, parent.this)
	// FIXME Make passing through of self.GlobalObject more general? Whenever newExecutionContext is passed a nil object?
	new.eval = true
	self.EnterExecutionContext(new)
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
		self.GlobalObject.defineProperty(reference.GetName(), value, 0111, strict)
	}
}

func (self *_runtime) _callNode(function *_object, environment *_functionEnvironment, node *_functionNode, this Value, argumentList []Value) Value {

	indexOfParameterName := make([]string, len(argumentList))
	// function(abc, def, ghi)
	// indexOfParameterName[0] = "abc"
	// indexOfParameterName[1] = "def"
	// indexOfParameterName[2] = "ghi"
	// ...

	for index, name := range node.ParameterList {
		value := UndefinedValue()
		if index < len(argumentList) {
			value = argumentList[index]
			indexOfParameterName[index] = name
		}
		self.localSet(name, value)
	}

	if !node.ArgumentsIsParameter {
		arguments := self.newArgumentsObject(indexOfParameterName, environment, len(argumentList))
		arguments.defineProperty("callee", toValue(function), 0101, false)
		environment.arguments = arguments
		self.localSet("arguments", toValue(arguments))
		for index, _ := range argumentList {
			if index < len(node.ParameterList) {
				continue
			}
			indexAsString := strconv.FormatInt(int64(index), 10)
			arguments.defineProperty(indexAsString, argumentList[index], 0111, false)
		}
	}

	self.declare("function", node.FunctionList)
	self.declare("variable", node.VariableList)

	self.evaluateBody(node.Body)

	return UndefinedValue()
}

func (self *_runtime) Call(function *_object, this Value, argumentList []Value, evalHint bool) (returnValue Value) {
	// Pass eval boolean through to EnterFunctionExecutionContext for further testing
	_functionEnvironment := self.EnterFunctionExecutionContext(function, this)
	defer func() {
		// TODO Catch any errant break/continue, etc. here?
		//		They should never get here, but we want to be
		//		very vocal if they do.
		self.LeaveExecutionContext()
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

	if evalHint {
		evalHint = function == self.eval // If evalHint is true, then it IS a direct eval
	}
	returnValue = function.functionValue().call.Dispatch(function, _functionEnvironment, self, this, argumentList, evalHint)
	return
}

func (self *_runtime) tryCatchEvaluate(inner func() Value) (resultValue Value, throw bool, throwValue Value, other *_result) {
	// resultValue = The value of the block (e.g. the last statement)
	// throw = Something was thrown
	// throwValue = The value of what was thrown
	// other = Something that changes flow (return, break, continue) that is not a throw
	// Otherwise, some sort of unknown panic happened, we'll just propagate it
	defer func() {
		if caught := recover(); caught != nil {
			switch caught := caught.(type) {
			case _result:
				switch caught.Kind {
				case resultThrow:
					throw = true
					throwValue = caught.Value
				case resultReturn, resultBreak, resultContinue:
					fallthrough
				default:
					other = &caught
				}
			case _error:
				throw = true
				throwValue = toValue(self.newError(caught.Name, caught.MessageValue()))
			case *_syntaxError:
				throw = true
				throwValue = toValue(self.newError("SyntaxError", toValue(caught.Message)))
			case Value:
				throw = true
				throwValue = caught
			default:
				panic(caught)
			}
		}
	}()

	resultValue = inner()
	return
}

func (self *_runtime) breakEvaluate(_labelSet map[string]bool, iterator *_iterator, inner func() Value) (returnValue Value) {
	defer func() {
		if caught := recover(); caught != nil {
			if result, ok := caught.(_result); ok {
				if result.Kind == resultBreak && _labelSet[result.Target] == true {
					if iterator != nil {
						returnValue = iterator.value
					}
					return
				}
			}
			panic(caught)
		}
	}()

	return inner()
}

func (self *_runtime) continueEvaluate(iterator *_iterator, _labelSet map[string]bool) (returnResult Value) {
	defer func() {
		if caught := recover(); caught != nil {
			if result, ok := caught.(_result); ok {
				if result.Kind == resultContinue && _labelSet[result.Target] == true {
					returnResult = emptyValue()
					return
				}
			}
			panic(caught)
		}
	}()
	for _, node := range iterator.queue {
		returnResult = self.evaluate(node)
		// TODO If not empty
		iterator.value = returnResult
	}
	return
}

func (self *_runtime) declare(kind string, declarationList []_declaration) {
	executionContext := self._executionContext(0)
	eval := executionContext.eval
	environment := executionContext.VariableEnvironment

	for _, _declaration := range declarationList {
		name := _declaration.Name
		if kind == "function" {
			value := self.evaluate(_declaration.Definition)
			if !environment.HasBinding(name) {
				environment.CreateMutableBinding(name, eval == true)
			}
			// TODO 10.5.5.e
			environment.SetMutableBinding(name, value, false) // TODO strict
		} else {
			if !environment.HasBinding(name) {
				environment.CreateMutableBinding(name, eval == true)
				environment.SetMutableBinding(name, UndefinedValue(), false) // TODO strict
			}
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

func (self *_runtime) ToValue(value interface{}) (Value, error) {
	result := UndefinedValue()
	err := catchPanic(func() {
		result = self.toValue(value)
	})
	return result, err
}

func (self *_runtime) toValue(value interface{}) Value {
	switch value := value.(type) {
	case Value:
		return value
	case func(FunctionCall) Value:
		return toValue(self.newNativeFunction(value))
	case _nativeFunction:
		return toValue(self.newNativeFunction(value))
	case Object, *Object, _object, *_object:
		// Nothing happens.
	default:
		{
			value := reflect.ValueOf(value)
			switch value.Kind() {
			case reflect.Ptr:
				switch reflect.Indirect(value).Kind() {
				case reflect.Struct:
					return toValue(self.newGoStructObject(value))
				case reflect.Array:
					return toValue(self.newGoArray(value))
				}
			case reflect.Struct:
				return toValue(self.newGoStructObject(value))
			case reflect.Map:
				return toValue(self.newGoMapObject(value))
			case reflect.Slice:
				return toValue(self.newGoSlice(value))
			case reflect.Array:
				return toValue(self.newGoArray(value))
			}
		}
	}
	return toValue(value)
}

func (runtime *_runtime) newGoSlice(value reflect.Value) *_object {
	self := runtime.newGoSliceObject(value)
	self.prototype = runtime.Global.ArrayPrototype
	return self
}

func (runtime *_runtime) newGoArray(value reflect.Value) *_object {
	self := runtime.newGoArrayObject(value)
	self.prototype = runtime.Global.ArrayPrototype
	return self
}

func (self *_runtime) run(source string) Value {
	return self.evaluate(mustParse(source))
}

func (self *_runtime) runSafe(source string) (Value, error) {
	result := UndefinedValue()
	err := catchPanic(func() {
		result = self.run(source)
	})
	switch result._valueType {
	case valueReference:
		result = self.GetValue(result)
	}
	return result, err
}
