package otto

import ()

type _functionObject struct {
	Call      _callFunction
	Construct _constructFunction
}

func (runtime *_runtime) newNativeFunctionObject(native _nativeFunction, length int, name string) *_object {
	self := runtime.newClassObject("Function")
	self._Function = &_functionObject{
		Call:      newNativeCallFunction(native, name),
		Construct: defaultConstructFunction,
	}
	self.stash.set("length", toValue(length), _propertyMode(0))
	return self
}

func (runtime *_runtime) newNodeFunctionObject(node *_functionNode, scopeEnvironment _environment) *_object {
	self := runtime.newClassObject("Function")
	self._Function = &_functionObject{
		Call:      newNodeCallFunction(node, scopeEnvironment),
		Construct: defaultConstructFunction,
	}
	self.stash.set("length", toValue(len(node.ParameterList)), _propertyMode(0))
	return self
}

func (runtime *_runtime) newBoundFunctionObject(target *_object, this Value, argumentList []Value) *_object {
	self := runtime.newClassObject("Function")
	self._Function = &_functionObject{
		Call:      newBoundCallFunction(target, this, argumentList),
		Construct: defaultConstructFunction,
	}
	// FIXME
	self.stash.set("length", toValue(0), _propertyMode(0))
	return self
}

func (self *_object) Call(this Value, argumentList ...interface{}) Value {
	if self._Function == nil {
		panic(newTypeError("%v is not a function", toValue(self)))
	}
	return self.runtime.Call(self, this, self.runtime.toValueArray(argumentList...), false)
	// ... -> runtime -> self.Function.Call.Dispatch -> ...
}

func (self *_object) Construct(this Value, argumentList ...interface{}) Value {
	if self._Function == nil {
		panic(newTypeError("%v is not a function", toValue(self)))
	}
	return self._Function.Construct(self, this, self.runtime.toValueArray(argumentList...))
}

func defaultConstructFunction(self *_object, this Value, argumentList []Value) Value {
	newObject := self.runtime.newObject()
	newObject.class = "Object"
	prototypeValue := self.get("prototype")
	if !prototypeValue.IsObject() {
		prototypeValue = toValue(self.runtime.Global.ObjectPrototype)
	}
	newObject.prototype = prototypeValue._object()
	newObjectValue := toValue(newObject)
	result := self.Call(newObjectValue, argumentList)
	if result.IsObject() {
		return result
	}
	return newObjectValue
}

func (self *_object) CallGet(name string) Value {
	return self.runtime.Call(self, toValue(self), []Value{toValue(name)}, false)
}

func (self *_object) CallSet(name string, value Value) {
	self.runtime.Call(self, toValue(self), []Value{toValue(name), value}, false)
}

// 15.3.5.3
func (self *_object) HasInstance(of Value) bool {
	if self._Function == nil {
		// We should not have a HasInstance method
		panic(newTypeError())
	}
	if !of.IsObject() {
		return false
	}
	prototype := self.get("prototype")
	if !prototype.IsObject() {
		panic(newTypeError())
	}
	prototypeObject := prototype._object()

	value := of._object().prototype
	for value != nil {
		if value == prototypeObject {
			return true
		}
		value = value.prototype
	}
	return false
}

type _functionSignature string

type _nativeFunction func(FunctionCall) Value

// _constructFunction
type _constructFunction func(*_object, Value, []Value) Value

// _callFunction
type _callFunction interface {
	Dispatch(*_object, *_functionEnvironment, *_runtime, Value, []Value, bool) Value
	Source() string
	ScopeEnvironment() _environment
	name() string
}

type _callFunction_ struct {
	scopeEnvironment _environment // Can be either Lexical or Variable
	_name            string
}

func (self _callFunction_) ScopeEnvironment() _environment {
	return self.scopeEnvironment
}

func (self _callFunction_) name() string {
	return self._name
}

// _nativeCallFunction
type _nativeCallFunction struct {
	_callFunction_
	Native _nativeFunction
}

func newNativeCallFunction(native _nativeFunction, name string) *_nativeCallFunction {
	self := &_nativeCallFunction{
		Native: native,
	}
	self._callFunction_._name = name
	return self
}

func (self _nativeCallFunction) Dispatch(_ *_object, _ *_functionEnvironment, runtime *_runtime, this Value, argumentList []Value, evalHint bool) Value {
	return self.Native(FunctionCall{
		runtime:      runtime,
		This:         this,
		ArgumentList: argumentList,
		evalHint:     evalHint,
	})
}

func (self _nativeCallFunction) Source() string {
	return ""
}

// _nodeCallFunction
type _nodeCallFunction struct {
	_callFunction_
	node *_functionNode
}

func newNodeCallFunction(node *_functionNode, scopeEnvironment _environment) *_nodeCallFunction {
	self := &_nodeCallFunction{
		node: node,
	}
	self.scopeEnvironment = scopeEnvironment
	return self
}

func (self _nodeCallFunction) Dispatch(function *_object, environment *_functionEnvironment, runtime *_runtime, this Value, argumentList []Value, _ bool) Value {
	return runtime._callNode(function, environment, self.node, this, argumentList)
}

func (self _nodeCallFunction) Source() string {
	return ""
}

type _boundCallFunction struct {
	_callFunction_
	target       *_object
	this         Value
	argumentList []Value
}

func newBoundCallFunction(target *_object, this Value, argumentList []Value) *_boundCallFunction {
	self := &_boundCallFunction{
		target:       target,
		this:         this,
		argumentList: argumentList,
	}
	return self
}

func (self _boundCallFunction) Dispatch(_ *_object, _ *_functionEnvironment, runtime *_runtime, this Value, argumentList []Value, _ bool) Value {
	argumentList = append(self.argumentList, argumentList...)
	return runtime.Call(self.target, self.this, argumentList, false)
}

func (self _boundCallFunction) Source() string {
	return ""
}

// FunctionCall{}

// FunctionCall is an enscapulation of a JavaScript function call.
type FunctionCall struct {
	runtime      *_runtime
	This         Value
	_thisObject  *_object
	ArgumentList []Value
	evalHint     bool
}

// Argument will return the value of the argument at the given index.
//
// If no such argument exists, undefined is returned.
func (self FunctionCall) Argument(index int) Value {
	return valueOfArrayIndex(self.ArgumentList, index)
}

func (self FunctionCall) slice(index int) []Value {
	if index < len(self.ArgumentList) {
		return self.ArgumentList[index:]
	}
	return []Value{}
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
	if thisObject.class != class {
		panic(newTypeError())
	}
	return self._thisObject
}

func (self FunctionCall) toObject(value Value) *_object {
	return self.runtime.toObject(value)
}
