# otto
--
    import "github.com/robertkrimen/otto"

Package otto is a JavaScript parser and interpreter written natively in Go.

http://godoc.org/github.com/robertkrimen/otto

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
    	result, _ := Otto.ToValue(2 + right)
    	return result
    })

    result, _ = Otto.Run(`
    	// First, say a greeting
    	sayHello("Xyzzy") // Hello, Xyzzy.
    	sayHello() // Hello, undefined

    	result = twoPlus(2.0) // 4
    `)

You can run (Go) JavaScript from the commandline with:
http://github.com/robertkrimen/otto/tree/master/otto

    $ go get -v github.com/robertkrimen/otto/otto

Run JavaScript by entering some source on stdin or by giving otto a filename:

    $ otto example.js

Optionally include the JavaScript utility-belt library, underscore, with this
import:

    import (
    	"github.com/robertkrimen/otto"
    	_ "github.com/robertkrimen/otto/underscore"
    )

    // Now every otto runtime will come loaded with underscore

For more information: http://github.com/robertkrimen/otto/tree/master/underscore

### Caveat Emptor

    * For now, otto is a hybrid ECMA3/ECMA5 interpreter. Parts of the specification are still works in progress.
    * For example, "use strict" will parse, but does nothing.
    * Error reporting needs to be improved.
    * Does not support the (?!) or (?=) regular expression syntax (because Go does not)
    * JavaScript considers a vertical tab (\000B <VT>) to be part of the whitespace class (\s), while RE2 does not.
    * Really, error reporting could use some improvement.


### Regular Expression Syntax

Go translates JavaScript-style regular expressions into something that is
"regexp" package compatible.

Unfortunately, JavaScript has positive lookahead, negative lookahead, and
backreferencing, all of which are not supported by Go's RE2-like engine:
https://code.google.com/p/re2/wiki/Syntax

A brief discussion of these limitations: "Regexp (?!re)"
https://groups.google.com/forum/?fromgroups=#%21topic/golang-nuts/7qgSDWPIh_E

More information about RE2: https://code.google.com/p/re2/

JavaScript considers a vertical tab (\000B <VT>) to be part of the whitespace
class (\s), while RE2 does not.


### Halting Problem

If you want to stop long running executions (like third-party code), you can use
the interrupt channel to do this:

    package main

    import (
        "errors"
        "fmt"
        Otto "github.com/robertkrimen/otto"
        "os"
        Time "time"
    )

    var Halt = errors.New("Halt")

    func main() {
        runUnsafe(`var abc = [];`)
        runUnsafe(`
        while (true) {
            // Loop forever
        }`)
    }

    func runUnsafe(unsafe string) {
        start := Time.Now()
        defer func() {
            duration := Time.Since(start)
            if caught := recover(); caught != nil {
                if caught == Halt {
                    fmt.Fprintf(os.Stderr, "Some code took to long! Stopping after: %v\n", duration)
                    return
                }
                panic(caught) // Something else happened, repanic!
            }
            fmt.Fprintf(os.Stderr, "Ran code successfully: %v\n", duration)
        }()
        otto := Otto.New()
        otto.Interrupt = make(chan func())
        go func() {
            Time.Sleep(2 * Time.Second) // Stop after two seconds
            otto.Interrupt <- func() {
                panic(Halt)
            }
        }()
        otto.Run(unsafe) // Here be dragons (risky code)
        otto.Interrupt = nil
    }

Where is setTimeout/setInterval?

These timing functions are not actually part of the ECMA-262 specification.
Typically, they belong to the `windows` object (in the browser). It would not be
difficult to provide something like these via Go, but you probably want to wrap
otto in an event loop in that case.

Here is some discussion of the problem:

* http://book.mixu.net/node/ch2.html

* http://en.wikipedia.org/wiki/Reentrancy_%28computing%29

* http://aaroncrane.co.uk/2009/02/perl_safe_signals/

## Usage

#### type FunctionCall

```go
type FunctionCall struct {
	This         Value
	ArgumentList []Value
	Otto         *Otto
}
```

FunctionCall is an encapsulation of a JavaScript function call.

#### func (FunctionCall) Argument

```go
func (self FunctionCall) Argument(index int) Value
```
Argument will return the value of the argument at the given index.

If no such argument exists, undefined is returned.

#### type Object

```go
type Object struct {
}
```

Object is the representation of a JavaScript object.

#### func (Object) Call

```go
func (self Object) Call(name string, argumentList ...interface{}) (Value, error)
```
Call the method specified by the given name, using self as the this value. It is
essentially equivalent to:

    var method, _ := self.Get(name)
    method.Call(self, argumentList...)

An undefined value and an error will result if:

    1. There is an error during conversion of the argument list
    2. The property is not actually a function
    3. An (uncaught) exception is thrown

#### func (Object) Class

```go
func (self Object) Class() string
```
Class will return the class string of the object.

The return value will (generally) be one of:

    Object
    Function
    Array
    String
    Number
    Boolean
    Date
    RegExp

#### func (Object) Get

```go
func (self Object) Get(name string) (Value, error)
```
Get the value of the property with the given name.

#### func (Object) Set

```go
func (self Object) Set(name string, value interface{}) error
```
Set the property of the given name to the given value.

An error will result if the setting the property triggers an exception (i.e.
read-only), or there is an error during conversion of the given value.

#### func (Object) Value

```go
func (self Object) Value() Value
```
Value will return self as a value.

#### type Otto

```go
type Otto struct {
	// Interrupt is a channel for interrupting the runtime. You can use this to halt a long running execution, for example.
	// See "Halting Problem" for more information.
	Interrupt chan func()
}
```

Otto is the representation of the JavaScript runtime. Each instance of Otto has
a self-contained namespace.

#### func  New

```go
func New() *Otto
```
New will allocate a new JavaScript runtime

#### func  Run

```go
func Run(source string) (*Otto, Value, error)
```
Run will allocate a new JavaScript runtime, run the given source on the
allocated runtime, and return the runtime, resulting value, and error (if any).

#### func (Otto) Call

```go
func (self Otto) Call(source string, this interface{}, argumentList ...interface{}) (Value, error)
```
Call the given JavaScript with a given this and arguments.

WARNING: 2013-05-19: This function is rough, and is in beta.

If this is nil, then some special handling takes place to determine the proper
this value, falling back to a "standard" invocation if necessary (where this is
undefined).

If source begins with "new " (A lowercase new followed by a space), then Call
will invoke the function constructor rather than performing a function call. In
this case, the this argument has no effect.

    // value is a String object
    value, _ := Otto.Call("Object", nil, "Hello, World.")

    // Likewise...
    value, _ := Otto.Call("new Object", nil, "Hello, World.")

    // This will perform a concat on the given array and return the result
    // value is [ 1, 2, 3, undefined, 4, 5, 6, 7, "abc" ]
    value, _ := Otto.Call(`[ 1, 2, 3, undefined, 4 ].concat`, nil, 5, 6, 7, "abc")

#### func (*Otto) Copy

```go
func (self *Otto) Copy() *Otto
```
Copy will create a copy/clone of the runtime.

Copy is useful for saving some processing time when creating many similar
runtimes.

This implementation is alpha-ish, and works by introspecting every part of the
runtime and reallocating and then relinking everything back together. Please
report if you notice any inadvertent sharing of data between copies.

#### func (Otto) Get

```go
func (self Otto) Get(name string) (Value, error)
```
Get the value of the top-level binding of the given name.

If there is an error (like the binding does not exist), then the value will be
undefined.

#### func (Otto) Object

```go
func (self Otto) Object(source string) (*Object, error)
```
Object will run the given source and return the result as an object.

For example, accessing an existing object:

    object, _ := Otto.Object(`Number`)

Or, creating a new object:

    object, _ := Otto.Object(`({ xyzzy: "Nothing happens." })`)

Or, creating and assigning an object:

    object, _ := Otto.Object(`xyzzy = {}`)
    object.Set("volume", 11)

If there is an error (like the source does not result in an object), then nil
and an error is returned.

#### func (Otto) Run

```go
func (self Otto) Run(source string) (Value, error)
```
Run will run the given source (parsing it first), returning the resulting value
and error (if any)

If the runtime is unable to parse source, then this function will return
undefined and the parse error (nothing will be evaluated in this case).

#### func (Otto) Set

```go
func (self Otto) Set(name string, value interface{}) error
```
Set the top-level binding of the given name to the given value.

Set will automatically apply ToValue to the given value in order to convert it
to a JavaScript value (type Value).

If there is an error (like the binding is read-only, or the ToValue conversion
fails), then an error is returned.

If the top-level binding does not exist, it will be created.

#### func (Otto) ToValue

```go
func (self Otto) ToValue(value interface{}) (Value, error)
```
ToValue will convert an interface{} value to a value digestible by
otto/JavaScript.

#### type Value

```go
type Value struct {
}
```

Value is the representation of a JavaScript value.

#### func  FalseValue

```go
func FalseValue() Value
```
FalseValue will return a value representing false.

It is equivalent to:

    ToValue(false)

#### func  NaNValue

```go
func NaNValue() Value
```
NaNValue will return a value representing NaN.

It is equivalent to:

    ToValue(math.NaN())

#### func  NullValue

```go
func NullValue() Value
```
NullValue will return a Value representing null.

#### func  ToValue

```go
func ToValue(value interface{}) (Value, error)
```
ToValue will convert an interface{} value to a value digestible by
otto/JavaScript This function will not work for advanced types (struct, map,
slice/array, etc.) and you probably should not use it.

ToValue may be deprecated and removed in the near future.

Try Otto.ToValue for a replacement.

#### func  TrueValue

```go
func TrueValue() Value
```
TrueValue will return a value representing true.

It is equivalent to:

    ToValue(true)

#### func  UndefinedValue

```go
func UndefinedValue() Value
```
UndefinedValue will return a Value representing undefined.

#### func (Value) Call

```go
func (value Value) Call(this Value, argumentList ...interface{}) (Value, error)
```
Call the value as a function with the given this value and argument list and
return the result of invocation. It is essentially equivalent to:

    value.apply(thisValue, argumentList)

An undefined value and an error will result if:

    1. There is an error during conversion of the argument list
    2. The value is not actually a function
    3. An (uncaught) exception is thrown

#### func (Value) Class

```go
func (value Value) Class() string
```
Class will return the class string of the value or the empty string if value is
not an object.

The return value will (generally) be one of:

    Object
    Function
    Array
    String
    Number
    Boolean
    Date
    RegExp

#### func (Value) Export

```go
func (self Value) Export() (interface{}, error)
```
Export will attempt to convert the value to a Go representation and return it
via an interface{} kind.

WARNING: The interface function will be changing soon to:

    Export() interface{}

If a reasonable conversion is not possible, then the original result is
returned.

    undefined   -> otto.Value (UndefinedValue())
    null        -> interface{}(nil)
    boolean     -> bool
    number      -> A number type (int, float32, uint64, ...)
    string      -> string
    Array       -> []interface{}
    Object      -> map[string]interface{}

#### func (Value) IsBoolean

```go
func (value Value) IsBoolean() bool
```
IsBoolean will return true if value is a boolean (primitive).

#### func (Value) IsDefined

```go
func (value Value) IsDefined() bool
```
IsDefined will return false if the value is undefined, and true otherwise.

#### func (Value) IsFunction

```go
func (value Value) IsFunction() bool
```
IsFunction will return true if value is a function.

#### func (Value) IsNaN

```go
func (value Value) IsNaN() bool
```
IsNaN will return true if value is NaN (or would convert to NaN).

#### func (Value) IsNull

```go
func (value Value) IsNull() bool
```
IsNull will return true if the value is null, and false otherwise.

#### func (Value) IsNumber

```go
func (value Value) IsNumber() bool
```
IsNumber will return true if value is a number (primitive).

#### func (Value) IsObject

```go
func (value Value) IsObject() bool
```
IsObject will return true if value is an object.

#### func (Value) IsPrimitive

```go
func (value Value) IsPrimitive() bool
```
IsPrimitive will return true if value is a primitive (any kind of primitive).

#### func (Value) IsString

```go
func (value Value) IsString() bool
```
IsString will return true if value is a string (primitive).

#### func (Value) IsUndefined

```go
func (value Value) IsUndefined() bool
```
IsUndefined will return true if the value is undefined, and false otherwise.

#### func (Value) Object

```go
func (value Value) Object() *Object
```
Object will return the object of the value, or nil if value is not an object.

This method will not do any implicit conversion. For example, calling this
method on a string primitive value will not return a String object.

#### func (Value) String

```go
func (value Value) String() string
```
String will return the value as a string.

This method will make return the empty string if there is an error.

#### func (Value) ToBoolean

```go
func (value Value) ToBoolean() (bool, error)
```
ToBoolean will convert the value to a boolean (bool).

    ToValue(0).ToBoolean() => false
    ToValue("").ToBoolean() => false
    ToValue(true).ToBoolean() => true
    ToValue(1).ToBoolean() => true
    ToValue("Nothing happens").ToBoolean() => true

If there is an error during the conversion process (like an uncaught exception),
then the result will be false and an error.

#### func (Value) ToFloat

```go
func (value Value) ToFloat() (float64, error)
```
ToFloat will convert the value to a number (float64).

    ToValue(0).ToFloat() => 0.
    ToValue(1.1).ToFloat() => 1.1
    ToValue("11").ToFloat() => 11.

If there is an error during the conversion process (like an uncaught exception),
then the result will be 0 and an error.

#### func (Value) ToInteger

```go
func (value Value) ToInteger() (int64, error)
```
ToInteger will convert the value to a number (int64).

    ToValue(0).ToInteger() => 0
    ToValue(1.1).ToInteger() => 1
    ToValue("11").ToInteger() => 11

If there is an error during the conversion process (like an uncaught exception),
then the result will be 0 and an error.

#### func (Value) ToString

```go
func (value Value) ToString() (string, error)
```
ToString will convert the value to a string (string).

    ToValue(0).ToString() => "0"
    ToValue(false).ToString() => "false"
    ToValue(1.1).ToString() => "1.1"
    ToValue("11").ToString() => "11"
    ToValue('Nothing happens.').ToString() => "Nothing happens."

If there is an error during the conversion process (like an uncaught exception),
then the result will be the empty string ("") and an error.

--
**godocdown** http://github.com/robertkrimen/godocdown
