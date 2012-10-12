/*
Package otto is a JavaScript parser and interpreter written natively in Go.

	// Create a new runtime
	Otto := otto.New()

	Otto.Run(`
		abc = 2 + 2
		console.log("The value of abc is " + abc)
		// The value of abc is 4
	`)

	value, err := Otto.Get("abc")
	{
		// value is an int64 with a value of 4
		value, _ := value.ToInteger()
	}

	Otto.Set("def", 11)
	Otto.Run(`
		console.log("The value of def is " + def)
		// The value of def is 11
	`)

	Otto.Set("xyzzy", "Nothing happens.")
	Otto.Run(`
		console.log(xyzzy.length) // 16
	`)

	value, _ = Otto.Run("xyzzy.length")
	{
		// value is an int64 with a value of 16
		value, _ := value.ToInteger()
	}

	value, err = Otto.Run("abcdefghijlmnopqrstuvwxyz.length")
	if err != nil {
		// err = ReferenceError: abcdefghijlmnopqrstuvwxyz is not defined
		// If there is an error, then value.IsUndefined() is true
		...
	}

Embedding a Go function in JavaScript:

	Otto.Set("sayHello", func(call otto.FunctionCall) otto.Value {
		fmt.Printf("Hello, %s.\n", call.Argument(0).String())
		return otto.UndefinedValue()
	})

	Otto.Set("twoPlus", func(call otto.FunctionCall) otto.Value {
		right, _ := call.Argument(0).ToInteger()
		result, _ := otto.ToValue(2 + right)
		return result
	})

	result, _ = Otto.Run(`
		// First, say a greeting
		sayHello("Xyzzy") // Hello, Xyzzy.
		sayHello() // Hello, undefined

		result = twoPlus(2.0) // 4
	`)

You can run (Go) JavaScript from the commandline with: http://github.com/robertkrimen/otto/tree/master/otto

	$ go get -v github.com/robertkrimen/otto/otto

Run JavaScript by entering some source on stdin or by giving otto a filename:

	$ otto example.js

Optionally include the JavaScript utility-belt library, underscore, with this import:

	import (
		"github.com/robertkrimen/otto"
		_ "github.com/robertkrimen/otto/underscore"
	)

	// Now every otto runtime will come loaded with underscore 

For more information: http://github.com/robertkrimen/otto/tree/master/underscore

Caveat Emptor

* For now, otto is a hybrid ECMA3/ECMA5 interpreter. Parts of the specification are still works in progress.
* For example, "use strict" will parse, but does nothing.
* Error reporting needs to be improved.
* Number.prototype.{toFixed,toExponential,toPrecision} are missing.
* Does not support the (?!) or (?=) regular expression syntax (because Go does not).
* Really, error reporting could use some improvement.

*/
package otto

import (
	"fmt"
	"github.com/robertkrimen/otto/registry"
)

// Otto is the representation of the JavaScript runtime. Each instance of Otto has a self-contained namespace.
type Otto struct {
	runtime *_runtime
}

// New will allocate a new JavaScript runtime
func New() *Otto {
	self := &Otto{
		runtime: newContext(),
	}
	self.Set("console", self.runtime.newConsole())

	registry.Apply(func(entry registry.Entry){
		self.Run(entry.Source())
	})

	return self
}

// Run will allocate a new JavaScript runtime, run the given source
// on the allocated runtime, and return the runtime, resulting value, and
// error (if any).
func Run(source string) (*Otto, Value, error) {
	otto := New()
	result, err := otto.Run(source)
	return otto, result, err
}

// Run will run the given source (parsing it first), returning the resulting value and error (if any)
//
// If the runtime is unable to parse the source, then this function will return undefined and the parse error (nothing
// will be evaluated in this case).
func (self Otto) Run(source string) (Value, error) {
	result := UndefinedValue()
	err := catchPanic(func(){
		result = self.run(source)
	})
	switch result._valueType {
	case valueReference:
		result = self.runtime.GetValue(result)
	}
	return result, err
}

func (self Otto) run(run interface{}) Value {
	switch value := run.(type) {
	case []byte:
		return self.runSource(string(value))
	case string:
		return self.runSource(value)
	case _node:
		return self.runNode(value)
	}
	panic(hereBeDragons("%v", run))
}

func (self Otto) runSource(run string) Value {
	return self.runtime.evaluate(mustParse(run))
}

func (self Otto) runNode(run _node) Value {
	return self.runtime.evaluate(run)
}

// Get the value of the top-level binding of the given name.
//
// If there is an error (like the binding not existing), then the value
// will be undefined.
func (self Otto) Get(name string) (Value, error) {
	result := UndefinedValue()
	err := catchPanic(func(){
		result = self.getValue(name)
	})
	return result, err
}

func (self Otto) getValue(name string) Value {
	return self.runtime.GlobalEnvironment.GetValue(name, false)
}

// Set the top-level binding of the given name to the given value.
//
// Set will automatically apply ToValue to the given value in order
// to convert it to a JavaScript value (type Value).
//
// If there is an error (like the binding being read-only, or the ToValue conversion
// failing), then an error is returned.
//
// If the top-level binding does not exist, it will be created.
func (self Otto) Set(name string, value interface{}) error {
	err := catchPanic(func(){
		self.setValue(name, self.runtime.toValue(value))
	})
	return err
}

func (self Otto) setValue(name string, value Value) {
	self.runtime.GlobalEnvironment.SetValue(name, value, false)
}

// Object will run the given source and return the result as an object.
//
// For example, accessing an existing object:
// 
//		object, _ := Otto.Object(`Number`)
//
// Or, creating a new object:
//
//		object, _ := Otto.Object(`{ xyzzy: "Nothing happens." }`) 
//
// Or, creating and assigning an object:
//
//		object, _ := Otto.Object(`xyzzy = {}`)
//		object.Set("volume", 11)
//
// If there is an error (like the source does not result in an object), then
// nil and an error is returned.
func (self Otto) Object(source string) (*Object, error) {
	var result Value
	err := catchPanic(func(){
		result = self.run(source)
	})
	if err != nil {
		return nil, err
	}
	if result.IsObject() {
		return result.Object(), nil
	}
	return nil, fmt.Errorf("Result was not an object")
}

// Object{}

// Object is the representation of a JavaScript object.
type Object struct {
	object *_object
	value Value
}

func _newObject(object *_object, value Value) *Object {
	// value MUST contain object!
	return &Object{
		object: object,
		value: value,
	}
}

// Call the method specified by the given name, using self as the this value.
// It is essentially equivalent to:
//
//		return self.Get(name).Call(self, argumentList)
//
// An undefined value and an error will result if:
//
//		1. There is an error during conversion of the argument list
//		2. The property is not actually a function
//		3. An (uncaught) exception is thrown
//
func (self Object) Call(name string, argumentList... interface{}) (Value, error) {
	function, err := self.Get(name)
	if err != nil {
		return UndefinedValue(), err
	}
	return function.Call(self.Value(), argumentList...)
}

// Value will return self as a value.
func (self Object) Value() Value {
	return self.value
}

// Get the value of the property with the given name.
func (self Object) Get(name string) (Value, error) {
	result := UndefinedValue()
	err := catchPanic(func(){
		result = self.object.Get(name)
	})
	return result, err
}

// Set the property of the given name to the given value.
//
// An error will result if the setting the property triggers an exception (i.e. read-only),
// or there is an error during conversion of the given value.
func (self Object) Set(name string, value interface{}) (error) {
	err := catchPanic(func(){
		self.object.Put(name, self.object.runtime.toValue(value), true)
	})
	return err
}

// Class will return the class string of the object.
//
// The return value will (generally) be one of:
//
//		Object
//		Function
//		Array
//		String
//		Number
//		Boolean
//		Date
//		RegExp
//
func (self Object) Class() string {
	return self.object.Class
}
