package otto

import (
)

type _functionObject struct {
	Call _callFunction
	Construct _constructFunction
}

func (runtime *_runtime) newNativeFunctionObject(native _nativeFunction, length int) *_object {
	self := runtime.newClassObject("Function")
	self.Function = &_functionObject{
		Call: newNativeCallFunction(native),
		Construct: defaultConstructFunction,
	}
	self.DefineOwnProperty("length", _property{Mode: 0, Value: toValue(length)}.toDefineProperty(), false)
    return self
}

func (runtime *_runtime) newNodeFunctionObject(node *_functionNode, scopeEnvironment _environment) *_object {
	self := runtime.newClassObject("Function")
	self.Function = &_functionObject{
		Call: newNodeCallFunction(node, scopeEnvironment),
		Construct: defaultConstructFunction,
	}
	self.DefineOwnValueProperty("length", toValue(len(node.ParameterList)), 0 /* -Write -Configure -Enumerate */, false)
	return self
}

func (self *_object) Call(this Value, argumentList... interface{}) Value {
	return self.runtime.Call(self, this, toValueArray(argumentList...))
	// ... -> runtime -> self.Function.Call.Dispatch -> ...
}

func (self *_object) Construct(this Value, argumentList... interface{}) Value {
	return self.Function.Construct(self, this, toValueArray(argumentList...))
}

func defaultConstructFunction(self *_object, this Value, argumentList []Value) Value {
	newObject := self.runtime.newObject()
	newObject.Class = "Object"
	newObject.Extensible = true
	prototypeValue := self.Get("prototype")
	if !prototypeValue.IsObject() {
		prototypeValue = toValue(self.runtime.Global.ObjectPrototype)
	}
	newObject.Prototype = prototypeValue._object()
	newObjectValue := toValue(newObject)
	result := self.Call(newObjectValue, argumentList)
	if result.IsObject() {
		return result
	}
	return newObjectValue
}

func (self *_object) CallGet(name string) Value {
	return self.runtime.Call(self, toValue(self), []Value{toValue(name)})
}

func (self *_object) CallSet(name string, value Value) {
	self.runtime.Call(self, toValue(self), []Value{toValue(name), value})
}

// 15.3.5.3
func (self *_object) HasInstance(of Value) bool {
	if !of.IsObject() {
		panic(newTypeError())
	}
	prototype := self.Get("prototype")
	if !prototype.IsObject() {
		panic(newTypeError())
	}
	ofPrototype := of._object().Prototype
	if ofPrototype == nil {
		return false
	}
	return ofPrototype == prototype._object()
}

type _functionSignature string

type _nativeFunction func(FunctionCall) Value

// _constructFunction
type _constructFunction func(*_object, Value, []Value) Value

// _callFunction
type _callFunction interface {
    Dispatch(*_functionEnvironment, *_runtime, Value, []Value) Value
	Source() string
	ScopeEnvironment() _environment
	Sign(_functionSignature)
	Signature() _functionSignature
}

type _callFunctionBase struct {
	scopeEnvironment _environment // Can be either Lexical or Variable
	signature _functionSignature
}

func (self _callFunctionBase) ScopeEnvironment() _environment {
	return self.scopeEnvironment
}

func (self *_callFunctionBase) Sign(signature _functionSignature) {
	self.signature = signature
}

func (self _callFunctionBase) Signature() _functionSignature {
	return self.signature
}

// _nativeCallFunction
type _nativeCallFunction struct {
	_callFunctionBase
	Native _nativeFunction
}

func newNativeCallFunction(native _nativeFunction) *_nativeCallFunction {
	return &_nativeCallFunction{
		Native: native,
	}
}

func (self _nativeCallFunction) Dispatch(_ *_functionEnvironment, runtime *_runtime, this Value, argumentList []Value) Value {
	return self.Native(FunctionCall{
		runtime: runtime,
		This: this,
		ArgumentList: argumentList,
	})
}

func (self _nativeCallFunction) Source() string {
	return ""
}

// _nodeCallFunction
type _nodeCallFunction struct {
	_callFunctionBase
	node *_functionNode
}

func newNodeCallFunction(node *_functionNode, scopeEnvironment _environment) *_nodeCallFunction {
	self := &_nodeCallFunction{
		node: node,
	}
	self.scopeEnvironment = scopeEnvironment
	return self
}

func (self _nodeCallFunction) Dispatch(environment *_functionEnvironment, runtime *_runtime, this Value, argumentList []Value) Value {
	return runtime._callNode(environment, self.node, this, argumentList)
}

func (self _nodeCallFunction) Source() string {
	return ""
}

// FunctionCall{}

// FunctionCall is an enscapulation of a JavaScript function call.
type FunctionCall struct {
	runtime *_runtime
	This Value
	_thisObject *_object
	ArgumentList []Value
}

// Argument will return the value of the argument at the given index.
//
// If no such argument exists, undefined is returned.
func (self FunctionCall) Argument(index int) Value {
	return valueOfArrayIndex(self.ArgumentList, index)
}

func (self *FunctionCall) thisObject() *_object {
	if self._thisObject == nil {
		this := self.runtime.GetValue(self.This) // FIXME Is this right?
		self._thisObject = self.runtime.toObject(this)
	}
	return self._thisObject
}

func (self *FunctionCall) thisClassObject(class string) *_object {
	thisObject := self.thisObject()
	if thisObject.Class != class {
		panic(newTypeError())
	}
	return self._thisObject
}

func (self FunctionCall) toObject(value Value) *_object {
	return self.runtime.toObject(value)
}
